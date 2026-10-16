import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// On-device SQLite database. One file per signed-in user, so accounts that
/// share a phone never see each other's data.
class AppDatabase {
  Future<Database>? _db;
  String? _uid;
  final _changes = StreamController<void>.broadcast();

  Future<Database> get instance {
    final db = _db;
    if (db == null) throw StateError('Local database is not open.');
    return db;
  }

  void open(String uid) {
    if (_uid == uid && _db != null) return;
    close();
    _uid = uid;
    _db = _openFile(uid);
  }

  Future<void> close() async {
    final pending = _db;
    _db = null;
    _uid = null;
    if (pending != null) {
      try {
        await (await pending).close();
      } catch (_) {}
    }
  }

  Future<Database> _openFile(String uid) async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'thesistrack_$uid.db'),
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE consultations (
            id TEXT PRIMARY KEY,
            groupId TEXT NOT NULL,
            groupName TEXT NOT NULL,
            adviserUid TEXT NOT NULL,
            adviserName TEXT NOT NULL,
            startsAt INTEGER NOT NULL,
            durationMins INTEGER NOT NULL,
            roster TEXT NOT NULL,
            notes TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE action_items (
            id TEXT PRIMARY KEY,
            consultationId TEXT NOT NULL,
            groupId TEXT NOT NULL,
            groupName TEXT NOT NULL,
            adviserUid TEXT NOT NULL,
            title TEXT NOT NULL,
            assignee TEXT,
            dueAt INTEGER,
            done INTEGER NOT NULL DEFAULT 0,
            doneAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )''');
        await db.execute(
          'CREATE INDEX idx_items_consultation ON action_items(consultationId)',
        );
        await db.execute('''
          CREATE TABLE outbox (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            collection TEXT NOT NULL,
            docId TEXT NOT NULL,
            op TEXT NOT NULL,
            data TEXT,
            createdAt INTEGER NOT NULL
          )''');
        await _createTitleTable(db);
        await _createMilestoneTable(db);
        await _createTaskTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createTitleTable(db);
        if (oldVersion < 3) await _createMilestoneTable(db);
        if (oldVersion < 4) await _createTaskTable(db);
      },
    );
  }

  Future<void> _createTitleTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS title_ideas (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        purpose TEXT NOT NULL,
        status TEXT NOT NULL,
        createdByUid TEXT NOT NULL,
        createdByName TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        comment TEXT,
        reviewedByName TEXT,
        reviewedAt INTEGER
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_titles_group ON title_ideas(groupId)',
    );
  }

  Future<void> _createMilestoneTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestones (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        slug TEXT NOT NULL,
        title TEXT NOT NULL,
        position INTEGER NOT NULL,
        status TEXT NOT NULL,
        dueAt INTEGER,
        comment TEXT,
        updatedByName TEXT,
        updatedAt INTEGER NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_milestones_group ON milestones(groupId)',
    );
  }

  Future<void> _createTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestone_tasks (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        milestoneId TEXT NOT NULL,
        title TEXT NOT NULL,
        assignee TEXT,
        dueAt INTEGER,
        done INTEGER NOT NULL DEFAULT 0,
        doneAt INTEGER,
        doneByName TEXT,
        createdByName TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_milestone ON milestone_tasks(milestoneId)',
    );
  }

  // ── change notifications (screens re-query when this fires) ──

  void notifyChanged() => _changes.add(null);

  Stream<T> watch<T>(Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;

    Future<void> emit() async {
      try {
        final value = await query();
        if (!controller.isClosed) controller.add(value);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  // ── outbox ──

  Future<void> enqueue(
      DatabaseExecutor ex,
      String collection,
      String docId,
      String op, [
        Map<String, dynamic>? data,
      ]) async {
    await ex.insert('outbox', {
      'collection': collection,
      'docId': docId,
      'op': op, // 'upsert' (merge) or 'delete'
      'data': data == null ? null : jsonEncode(data),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, Object?>?> nextOp() async {
    final db = await instance;
    final rows = await db.query('outbox', orderBy: 'seq ASC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> removeOp(int seq) async {
    final db = await instance;
    await db.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
    notifyChanged();
  }

  Future<bool> hasPending(String collection, String docId) async {
    final db = await instance;
    final n = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM outbox WHERE collection = ? AND docId = ?',
        [collection, docId],
      ),
    );
    return (n ?? 0) > 0;
  }

  Future<int> pendingCount() async {
    final db = await instance;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM outbox'),
    ) ??
        0;
  }
}