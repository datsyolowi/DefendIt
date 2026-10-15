import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/firestore_paths.dart';
import '../local/app_database.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/title_idea.dart';
import '../sync/sync_service.dart';

class TitleFailure implements Exception {
  TitleFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads come from the local sqflite database. Writes go to sqflite and the
/// outbox, then trigger a sync. Only [watchRemoteTitles] touches Firestore
/// directly (the adviser's preview of a group they don't advise yet).
class TitleRepository {
  TitleRepository(this._db, this._sync, {FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _db;
  final SyncService _sync;
  final FirebaseFirestore _fs;
  static const _uuid = Uuid();
  static const _table = 'title_ideas';

  String _path(String groupId) =>
      '${FirestorePaths.groups}/$groupId/${FirestorePaths.titles}';

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void _afterWrite() {
    _db.notifyChanged();
    _sync.flush();
  }

  // ── reads ──

  /// Local, oldest first, so the first title is the group's lead idea.
  Stream<List<TitleIdea>> watchTitles(String groupId) =>
      _db.watch<List<TitleIdea>>(() async {
        final db = await _db.instance;
        final rows = await db.query(_table,
            where: 'groupId = ?',
            whereArgs: [groupId],
            orderBy: 'createdAt ASC');
        return rows.map(TitleIdea.fromRow).toList();
      });

  /// Firestore only, for previewing a group before accepting it.
  Stream<List<TitleIdea>> watchRemoteTitles(String groupId) {
    return _fs.collection(_path(groupId)).snapshots().map((snap) {
      final list =
      snap.docs.map((d) => TitleIdea.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<TitleIdea?> _find(String groupId, String id) async {
    final db = await _db.instance;
    final rows = await db.query(_table,
        where: 'id = ? AND groupId = ?', whereArgs: [id, groupId], limit: 1);
    return rows.isEmpty ? null : TitleIdea.fromRow(rows.first);
  }

  void _requireMember(AppUser student, Group group) {
    if (student.role != UserRole.student ||
        !group.memberUids.contains(student.uid)) {
      throw TitleFailure('Only members of this group can manage its title ideas.');
    }
  }

  // ── student writes (work offline) ──

  Future<void> addTitle({
    required AppUser student,
    required Group group,
    required String title,
    required String description,
    required String purpose,
  }) async {
    _requireMember(student, group);

    final now = _now();
    final idea = TitleIdea(
      id: _uuid.v4(),
      groupId: group.id,
      title: title.trim(),
      description: description.trim(),
      purpose: purpose.trim(),
      status: TitleStatus.pending,
      createdByUid: student.uid,
      createdByName: student.name,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.insert(_table, idea.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _db.enqueue(txn, _path(group.id), idea.id, 'upsert', idea.toMap());
    });
    _afterWrite();
  }

  /// Editing sends the idea back to "pending" and clears the old review.
  Future<void> updateTitle({
    required AppUser student,
    required Group group,
    required String titleId,
    required String title,
    required String description,
    required String purpose,
  }) async {
    _requireMember(student, group);

    final current = await _find(group.id, titleId);
    if (current == null) throw TitleFailure('This title idea no longer exists.');
    if (!current.studentCanEdit) {
      throw TitleFailure('Only pending or "needs polish" titles can be edited.');
    }

    final fields = <String, Object?>{
      'title': title.trim(),
      'description': description.trim(),
      'purpose': purpose.trim(),
      'status': TitleStatus.pending.name,
      'comment': null,
      'reviewedByName': null,
      'reviewedAt': null,
      'updatedAt': _now(),
    };

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(_table, fields, where: 'id = ?', whereArgs: [titleId]);
      await _db.enqueue(txn, _path(group.id), titleId, 'upsert', fields);
    });
    _afterWrite();
  }

  Future<void> deleteTitle({
    required AppUser student,
    required Group group,
    required String titleId,
  }) async {
    _requireMember(student, group);

    final current = await _find(group.id, titleId);
    if (current == null) return;
    if (!current.studentCanDelete) {
      throw TitleFailure('Approved titles can\'t be deleted.');
    }

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.delete(_table, where: 'id = ?', whereArgs: [titleId]);
      await _db.enqueue(txn, _path(group.id), titleId, 'delete');
    });
    _afterWrite();
  }

  // ── adviser write (works offline) ──

  Future<void> reviewTitle({
    required AppUser adviser,
    required Group group,
    required String titleId,
    required TitleStatus status,
    required String comment,
  }) async {
    if (adviser.role != UserRole.adviser || group.adviserUid != adviser.uid) {
      throw TitleFailure('Only this group\'s adviser can review its titles.');
    }
    if (status == TitleStatus.pending) {
      throw TitleFailure('Choose Approved, Needs polish, or Rejected.');
    }
    final clean = comment.trim();
    if (status != TitleStatus.approved && clean.isEmpty) {
      throw TitleFailure('Add a comment explaining what should change.');
    }

    final current = await _find(group.id, titleId);
    if (current == null) {
      throw TitleFailure(
          'This title idea has not synced to your phone yet. Connect to the internet and try again.');
    }

    final now = _now();
    final fields = <String, Object?>{
      'status': status.name,
      'comment': clean.isEmpty ? null : clean,
      'reviewedByName': adviser.name,
      'reviewedAt': now,
      'updatedAt': now,
    };

    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(_table, fields, where: 'id = ?', whereArgs: [titleId]);
      await _db.enqueue(txn, _path(group.id), titleId, 'upsert', fields);
    });
    _afterWrite();
  }
}