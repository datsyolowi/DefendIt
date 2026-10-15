import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/firestore_paths.dart';
import '../local/app_database.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/milestone.dart';
import '../remote/network_guard.dart';
import '../sync/sync_service.dart';

class MilestoneFailure implements Exception {
  MilestoneFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MilestoneProgress {
  const MilestoneProgress({required this.total, required this.approved});
  final int total;
  final int approved;
  double get ratio => total == 0 ? 0 : approved / total;
}

/// Reads come from the local sqflite database. Writes go to sqflite and the
/// outbox, then trigger a sync.
class MilestoneRepository {
  MilestoneRepository(this._db, this._sync, {FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _db;
  final SyncService _sync;
  final FirebaseFirestore _fs;
  static const _table = 'milestones';

  String _path(String groupId) =>
      '${FirestorePaths.groups}/$groupId/${FirestorePaths.milestones}';

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

  /// Approved / total milestones for every group on this phone.
  Stream<Map<String, MilestoneProgress>> watchProgress() =>
      _db.watch<Map<String, MilestoneProgress>>(() async {
        final db = await _db.instance;
        final rows = await db.rawQuery('''
          SELECT groupId,
                 COUNT(*) AS total,
                 SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved
          FROM milestones GROUP BY groupId''');
        return {
          for (final r in rows)
            r['groupId'] as String: MilestoneProgress(
              total: (r['total'] as num).toInt(),
              approved: (r['approved'] as num?)?.toInt() ?? 0,
            ),
        };
      });

  Future<Milestone?> _find(String id) async {
    final db = await _db.instance;
    final rows =
    await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Milestone.fromRow(rows.first);
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

  // ── writes (work offline) ──

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
    if (current == null) {
      throw MilestoneFailure(
          'This milestone has not synced to your phone yet. Connect to the internet and try again.');
    }

    final allowed =
    isAdviser ? current.status.adviserNext : current.status.studentNext;
    if (!allowed.contains(to)) {
      throw MilestoneFailure(isAdviser
          ? 'Only milestones submitted for review can be approved or sent back.'
          : 'That status change isn\'t allowed right now.');
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
    if (await _find(milestone.id) == null) {
      throw MilestoneFailure(
          'This milestone has not synced to your phone yet. Connect to the internet and try again.');
    }

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