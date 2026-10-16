import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/firestore_paths.dart';
import '../local/app_database.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/milestone.dart';
import '../models/milestone_task.dart';
import '../remote/network_guard.dart';
import '../sync/sync_service.dart';

class MilestoneFailure implements Exception {
  MilestoneFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// [ratio] is the average completion across milestones: an approved milestone
/// counts as 1.0, others count as their share of finished tasks.
class MilestoneProgress {
  const MilestoneProgress({
    required this.total,
    required this.approved,
    required this.ratio,
  });
  final int total;
  final int approved;
  final double ratio;
}

/// Reads come from the local sqflite database. Writes go to sqflite and the
/// outbox, then trigger a sync.
class MilestoneRepository {
  MilestoneRepository(this._db, this._sync, {FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _db;
  final SyncService _sync;
  final FirebaseFirestore _fs;
  static const _uuid = Uuid();
  static const _table = 'milestones';
  static const _taskTable = 'milestone_tasks';
  static const _notSynced =
      'This milestone has not synced to your phone yet. Connect to the internet and try again.';

  String _path(String groupId) =>
      '${FirestorePaths.groups}/$groupId/${FirestorePaths.milestones}';

  String _taskPath(String groupId) =>
      '${FirestorePaths.groups}/$groupId/${FirestorePaths.tasks}';

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void _afterWrite() {
    _db.notifyChanged();
    _sync.flush();
  }

  // ── reads (local) ──

  Stream<List<Milestone>> watchMilestones(String groupId) =>
      _db.watch<List<Milestone>>(() async {
        final db = await _db.instance;
        final rows = await db.query(_table,
            where: 'groupId = ?',
            whereArgs: [groupId],
            orderBy: 'position ASC');
        return rows.map(Milestone.fromRow).toList();
      });

  Stream<Milestone?> watchMilestone(String id) =>
      _db.watch<Milestone?>(() => _find(id));

  Stream<List<MilestoneTask>> watchTasks(String milestoneId) =>
      _db.watch<List<MilestoneTask>>(() async {
        final db = await _db.instance;
        final rows = await db.query(_taskTable,
            where: 'milestoneId = ?',
            whereArgs: [milestoneId],
            orderBy: 'done ASC, createdAt ASC');
        return rows.map(MilestoneTask.fromRow).toList();
      });

  /// Finished / total tasks for each milestone of one group.
  Stream<Map<String, TaskCount>> watchTaskCounts(String groupId) =>
      _db.watch<Map<String, TaskCount>>(() async {
        final db = await _db.instance;
        final rows = await db.rawQuery('''
          SELECT milestoneId, COUNT(*) AS total, SUM(done) AS done
          FROM milestone_tasks WHERE groupId = ? GROUP BY milestoneId''',
            [groupId]);
        return {
          for (final r in rows)
            r['milestoneId'] as String: TaskCount(
              done: (r['done'] as num?)?.toInt() ?? 0,
              total: (r['total'] as num).toInt(),
            ),
        };
      });

  /// Overall progress for every group on this phone.
  Stream<Map<String, MilestoneProgress>> watchProgress() =>
      _db.watch<Map<String, MilestoneProgress>>(() async {
        final db = await _db.instance;
        final milestones =
        await db.query(_table, columns: ['id', 'groupId', 'status']);
        final taskRows = await db.rawQuery('''
          SELECT milestoneId, COUNT(*) AS total, SUM(done) AS done
          FROM milestone_tasks GROUP BY milestoneId''');
        final counts = {
          for (final r in taskRows)
            r['milestoneId'] as String: TaskCount(
              done: (r['done'] as num?)?.toInt() ?? 0,
              total: (r['total'] as num).toInt(),
            ),
        };

        final byGroup = <String, List<double>>{};
        final approved = <String, int>{};
        for (final m in milestones) {
          final gid = m['groupId'] as String;
          final isApproved = m['status'] == MilestoneStatus.approved.name;
          final c = counts[m['id']];
          final completion = isApproved ? 1.0 : (c?.ratio ?? 0.0);
          byGroup.putIfAbsent(gid, () => []).add(completion);
          if (isApproved) approved[gid] = (approved[gid] ?? 0) + 1;
        }
        return {
          for (final e in byGroup.entries)
            e.key: MilestoneProgress(
              total: e.value.length,
              approved: approved[e.key] ?? 0,
              ratio: e.value.reduce((a, b) => a + b) / e.value.length,
            ),
        };
      });

  Future<Milestone?> _find(String id) async {
    final db = await _db.instance;
    final rows =
    await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Milestone.fromRow(rows.first);
  }

  Future<MilestoneTask?> _findTask(String id) async {
    final db = await _db.instance;
    final rows = await db
        .query(_taskTable, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : MilestoneTask.fromRow(rows.first);
  }

  Future<TaskCount> _countTasks(String milestoneId) async {
    final db = await _db.instance;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total, SUM(done) AS done
      FROM milestone_tasks WHERE milestoneId = ?''', [milestoneId]);
    final r = rows.first;
    return TaskCount(
      done: (r['done'] as num?)?.toInt() ?? 0,
      total: (r['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── setup for groups created before milestones existed (online) ──

  Future<void> ensureSeeded(Group group) async {
    if (!await isOnline()) {
      throw MilestoneFailure('Connect to the internet once to set up milestones.');
    }
    final col = _fs.collection(_path(group.id));
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return; // they arrive through sync

    final batch = _fs.batch();
    for (final m in Milestone.defaults(group.id)) {
      batch.set(col.doc(m.id), m.toMap());
    }
    await batch.commit();
  }

  // ── guards ──

  void _requireMember(AppUser actor, Group group) {
    if (actor.role != UserRole.student ||
        !group.memberUids.contains(actor.uid)) {
      throw MilestoneFailure('Only members of this group can manage its tasks.');
    }
  }

  Future<Milestone> _requireEditable(String milestoneId) async {
    final m = await _find(milestoneId);
    if (m == null) throw MilestoneFailure(_notSynced);
    if (!m.status.allowsTaskEdits) {
      throw MilestoneFailure(
          'Tasks are locked while this milestone is under review or approved.');
    }
    return m;
  }

  // ── task writes (students; work offline) ──

  Future<void> addTask({
    required AppUser actor,
    required Group group,
    required Milestone milestone,
    required String title,
    String? assignee,
    DateTime? due,
  }) async {
    _requireMember(actor, group);
    final current = await _requireEditable(milestone.id);

    final now = _now();
    final task = MilestoneTask(
      id: _uuid.v4(),
      groupId: group.id,
      milestoneId: milestone.id,
      title: title.trim(),
      assignee: assignee,
      dueAt: due?.millisecondsSinceEpoch,
      createdByName: actor.name,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.insert(_taskTable, task.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _db.enqueue(
          txn, _taskPath(group.id), task.id, 'upsert', task.toMap());

      // The first task starts the milestone automatically.
      if (current.status == MilestoneStatus.notStarted) {
        final fields = <String, Object?>{
          'status': MilestoneStatus.inProgress.name,
          'updatedByName': actor.name,
          'updatedAt': now,
        };
        await txn.update(_table, fields,
            where: 'id = ?', whereArgs: [current.id]);
        await _db.enqueue(txn, _path(group.id), current.id, 'upsert', fields);
      }
    });
    _afterWrite();
  }

  Future<void> updateTask({
    required AppUser actor,
    required Group group,
    required MilestoneTask task,
    required String title,
    String? assignee,
    DateTime? due,
  }) async {
    _requireMember(actor, group);
    await _requireEditable(task.milestoneId);
    if (await _findTask(task.id) == null) {
      throw MilestoneFailure('This task no longer exists.');
    }

    final fields = <String, Object?>{
      'title': title.trim(),
      'assignee': assignee,
      'dueAt': due?.millisecondsSinceEpoch,
      'updatedAt': _now(),
    };
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(_taskTable, fields,
          where: 'id = ?', whereArgs: [task.id]);
      await _db.enqueue(txn, _taskPath(group.id), task.id, 'upsert', fields);
    });
    _afterWrite();
  }

  Future<void> setTaskDone({
    required AppUser actor,
    required Group group,
    required MilestoneTask task,
    required bool done,
  }) async {
    _requireMember(actor, group);
    await _requireEditable(task.milestoneId);
    if (await _findTask(task.id) == null) {
      throw MilestoneFailure('This task no longer exists.');
    }

    final now = _now();
    final doneAt = done ? now : null;
    final doneBy = done ? actor.name : null;
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(
          _taskTable,
          {
            'done': done ? 1 : 0,
            'doneAt': doneAt,
            'doneByName': doneBy,
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [task.id]);
      // Only the changed fields travel, so a tick never overwrites the title.
      await _db.enqueue(txn, _taskPath(group.id), task.id, 'upsert', {
        'done': done,
        'doneAt': doneAt,
        'doneByName': doneBy,
        'updatedAt': now,
      });
    });
    _afterWrite();
  }

  Future<void> deleteTask({
    required AppUser actor,
    required Group group,
    required MilestoneTask task,
  }) async {
    _requireMember(actor, group);
    await _requireEditable(task.milestoneId);

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.delete(_taskTable, where: 'id = ?', whereArgs: [task.id]);
      await _db.enqueue(txn, _taskPath(group.id), task.id, 'delete');
    });
    _afterWrite();
  }

  // ── milestone status (students submit, the adviser reviews) ──

  Future<void> changeStatus({
    required AppUser actor,
    required Group group,
    required Milestone milestone,
    required MilestoneStatus to,
    String comment = '',
  }) async {
    final isAdviser =
        actor.role == UserRole.adviser && group.adviserUid == actor.uid;
    final isMember =
        actor.role == UserRole.student && group.memberUids.contains(actor.uid);
    if (!isAdviser && !isMember) {
      throw MilestoneFailure('You can\'t change this group\'s milestones.');
    }

    final current = await _find(milestone.id);
    if (current == null) throw MilestoneFailure(_notSynced);

    final allowed =
    isAdviser ? current.status.adviserNext : current.status.studentNext;
    if (!allowed.contains(to)) {
      throw MilestoneFailure(isAdviser
          ? 'Only milestones submitted for review can be approved or sent back.'
          : 'That status change isn\'t allowed right now.');
    }

    // A group earns the right to submit: tasks exist and all are done.
    if (isMember && to == MilestoneStatus.forReview) {
      final c = await _countTasks(current.id);
      if (c.total == 0) {
        throw MilestoneFailure(
            'Add at least one task before submitting for review.');
      }
      if (c.done < c.total) {
        final left = c.total - c.done;
        throw MilestoneFailure(
            'Finish the remaining $left task${left == 1 ? '' : 's'} before submitting.');
      }
    }

    final clean = comment.trim();
    if (isAdviser && to == MilestoneStatus.needsRevision && clean.isEmpty) {
      throw MilestoneFailure('Add a comment explaining what to revise.');
    }

    final fields = <String, Object?>{
      'status': to.name,
      'updatedByName': actor.name,
      'updatedAt': _now(),
    };
    // Only the adviser writes feedback, so a student's status change never
    // erases it.
    if (isAdviser) fields['comment'] = clean.isEmpty ? null : clean;

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(_table, fields,
          where: 'id = ?', whereArgs: [milestone.id]);
      await _db.enqueue(
          txn, _path(group.id), milestone.id, 'upsert', fields);
    });
    _afterWrite();
  }

  Future<void> setDue({
    required AppUser adviser,
    required Group group,
    required Milestone milestone,
    required DateTime? due,
  }) async {
    if (adviser.role != UserRole.adviser || group.adviserUid != adviser.uid) {
      throw MilestoneFailure('Only this group\'s adviser can set due dates.');
    }
    if (await _find(milestone.id) == null) throw MilestoneFailure(_notSynced);

    final fields = <String, Object?>{
      'dueAt': due?.millisecondsSinceEpoch,
      'updatedAt': _now(),
    };
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(_table, fields,
          where: 'id = ?', whereArgs: [milestone.id]);
      await _db.enqueue(
          txn, _path(group.id), milestone.id, 'upsert', fields);
    });
    _afterWrite();
  }
}