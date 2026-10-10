import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:sqflite/sqflite.dart';
import '../../core/constants/firestore_paths.dart';
import '../local/app_database.dart';
import '../models/action_item.dart';
import '../models/consultation.dart';
import '../models/group.dart';
import '../models/slot.dart';
import '../remote/network_guard.dart';
import '../sync/sync_service.dart';

class ConsultationFailure implements Exception {
  ConsultationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The UI only talks to this class. Every read comes from sqflite; every
/// write goes to sqflite + the outbox, then triggers a sync.
class ConsultationRepository {
  ConsultationRepository(this._db, this._sync, {FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _db;
  final SyncService _sync;
  final FirebaseFirestore _fs;
  static const _uuid = Uuid();

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void _afterWrite() {
    _db.notifyChanged();
    _sync.flush();
  }

  // ── reads (local) ──

  Stream<Consultation?> watchConsultation(String id) =>
      _db.watch<Consultation?>(() async {
        final db = await _db.instance;
        final rows =
        await db.query('consultations', where: 'id = ?', whereArgs: [id]);
        return rows.isEmpty ? null : Consultation.fromRow(rows.first);
      });

  Stream<List<ActionItem>> watchItems(String consultationId) =>
      _db.watch<List<ActionItem>>(() async {
        final db = await _db.instance;
        final rows = await db.query('action_items',
            where: 'consultationId = ?',
            whereArgs: [consultationId],
            orderBy: 'done ASC, createdAt ASC');
        return rows.map(ActionItem.fromRow).toList();
      });

  /// Not-done items across all consultations, soonest due first.
  Stream<List<ActionItem>> watchOpenItems({int limit = 4}) =>
      _db.watch<List<ActionItem>>(() async {
        final db = await _db.instance;
        final rows = await db.rawQuery('''
          SELECT * FROM action_items
          WHERE done = 0
          ORDER BY CASE WHEN dueAt IS NULL THEN 1 ELSE 0 END, dueAt, createdAt
          LIMIT ?''', [limit]);
        return rows.map(ActionItem.fromRow).toList();
      });

  Future<bool> exists(String id) async {
    final db = await _db.instance;
    final rows = await db.query('consultations',
        columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  // ── adviser: open (or create) the consultation for a booked slot ──

  Future<Consultation> openForAdviser(Slot slot) async {
    final db = await _db.instance;
    final local = await db
        .query('consultations', where: 'id = ?', whereArgs: [slot.id]);
    if (local.isNotEmpty) return Consultation.fromRow(local.first);

    if (!slot.isBooked || slot.bookedGroupId == null) {
      throw ConsultationFailure('This slot is not booked.');
    }
    if (!await isOnline()) {
      throw ConsultationFailure(
          'Connect to the internet to start this consultation. After that it works offline.');
    }

    // Already created from another device? Use it as is.
    final remote =
    await _fs.collection(FirestorePaths.consultations).doc(slot.id).get();
    if (remote.exists) {
      final c = Consultation.fromMap(remote.data()!, remote.id);
      await db.insert('consultations', c.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      _db.notifyChanged();
      return c;
    }

    final groupDoc =
    await _fs.collection(FirestorePaths.groups).doc(slot.bookedGroupId).get();
    final roster = Group.fromMap(groupDoc.data() ?? {}, groupDoc.id).roster;

    final now = _now();
    final c = Consultation(
      id: slot.id,
      groupId: slot.bookedGroupId!,
      groupName: slot.bookedGroupName ?? '',
      adviserUid: slot.adviserUid,
      adviserName: slot.adviserName,
      startsAt: slot.startsAt,
      durationMins: slot.durationMins,
      roster: roster,
      notes: '',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('consultations', c.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _db.enqueue(
          txn, FirestorePaths.consultations, c.id, 'upsert', c.toMap());
    });
    _afterWrite();
    return c;
  }

  // ── writes (local first) ──

  Future<void> saveNotes(Consultation c, String notes) async {
    final now = _now();
    final clean = notes.trim();
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update('consultations', {'notes': clean, 'updatedAt': now},
          where: 'id = ?', whereArgs: [c.id]);
      await _db.enqueue(txn, FirestorePaths.consultations, c.id, 'upsert',
          {'notes': clean, 'updatedAt': now});
    });
    _afterWrite();
  }

  Future<void> addItem(
      Consultation c, {
        required String title,
        String? assignee,
        DateTime? due,
      }) async {
    final now = _now();
    final item = ActionItem(
      id: _uuid.v4(),
      consultationId: c.id,
      groupId: c.groupId,
      groupName: c.groupName,
      adviserUid: c.adviserUid,
      title: title.trim(),
      assignee: assignee,
      dueAt: due?.millisecondsSinceEpoch,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.insert('action_items', item.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _db.enqueue(
          txn, FirestorePaths.actionItems, item.id, 'upsert', item.toMap());
    });
    _afterWrite();
  }

  Future<void> setDone(ActionItem item, bool done) async {
    final now = _now();
    final doneAt = done ? now : null;
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.update(
          'action_items',
          {'done': done ? 1 : 0, 'doneAt': doneAt, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [item.id]);
      // Only the changed fields travel, so a tick never overwrites the title.
      await _db.enqueue(txn, FirestorePaths.actionItems, item.id, 'upsert',
          {'done': done, 'doneAt': doneAt, 'updatedAt': now});
    });
    _afterWrite();
  }

  Future<void> deleteItem(ActionItem item) async {
    final db = await _db.instance;
    await db.transaction((txn) async {
      await txn.delete('action_items', where: 'id = ?', whereArgs: [item.id]);
      await _db.enqueue(txn, FirestorePaths.actionItems, item.id, 'delete');
    });
    _afterWrite();
  }
}