import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/firestore_paths.dart';
import '../local/app_database.dart';
import '../models/action_item.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/group.dart';
import '../models/milestone.dart';
import '../models/title_idea.dart';
import '../repositories/group_repository.dart';

/// Keeps the local sqflite database and Firestore in step:
///  - push: replays the outbox (oldest first) whenever we are online
///  - pull: Firestore listeners write remote changes into sqflite
class SyncService extends ChangeNotifier {
  SyncService(this._db, this._fs, this._groups);

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final GroupRepository _groups;

  AppUser? _user;
  StreamSubscription<List<ConnectivityResult>>? _net;
  StreamSubscription<List<Group>>? _groupSub;
  StreamSubscription<int>? _pendingSub;
  final List<StreamSubscription<dynamic>> _adviserSubs = [];
  final List<StreamSubscription<dynamic>> _groupSubs = [];
  String _groupKey = '\u0000';

  bool _online = true;
  bool _syncing = false;
  bool _flushing = false;
  int _pending = 0;
  String? _lastError;

  bool get online => _online;
  bool get syncing => _syncing;
  int get pending => _pending;
  String? get lastError => _lastError;

  void start(AppUser user) {
    if (_user?.uid == user.uid) return;
    stop();
    _user = user;
    _db.open(user.uid);

    _pendingSub = _db.watch<int>(_db.pendingCount).listen((n) {
      _pending = n;
      notifyListeners();
    }, onError: (_) {});

    _net = Connectivity().onConnectivityChanged.listen(_onNet);
    Connectivity().checkConnectivity().then(_onNet);

    if (user.role == UserRole.adviser) _listenAdviserDocs(user.uid);
    _groupSub = _groups.watchMyGroups(user).listen(_onGroups, onError: (_) {});
  }

  /// Called when the signed-in user leaves the app shell (sign out).
  void stop() {
    _net?.cancel();
    _groupSub?.cancel();
    _pendingSub?.cancel();
    _cancelAll(_adviserSubs);
    _cancelAll(_groupSubs);
    _net = null;
    _groupSub = null;
    _pendingSub = null;
    _groupKey = '\u0000';
    _user = null;
    _pending = 0;
    _db.close();
  }

  void _cancelAll(List<StreamSubscription<dynamic>> subs) {
    for (final s in subs) {
      s.cancel();
    }
    subs.clear();
  }

  void _onNet(List<ConnectivityResult> results) {
    if (_user == null) return;
    final on = results.any((r) => r != ConnectivityResult.none);
    if (on != _online) {
      _online = on;
      notifyListeners();
    }
    if (on) flush();
  }

  // ── push (local → cloud) ──

  Future<void> flush() async {
    if (_flushing || _user == null || !_online) return;
    _flushing = true;
    _syncing = true;
    notifyListeners();
    try {
      while (_user != null && _online) {
        final op = await _db.nextOp();
        if (op == null) break;
        await _push(op).timeout(const Duration(seconds: 12));
        await _db.removeOp(op['seq'] as int);
      }
      _lastError = null;
    } catch (e) {
      _lastError = '$e'; // op stays in the outbox and is retried later
    } finally {
      _flushing = false;
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _push(Map<String, Object?> op) async {
    // 'collection' may be a nested path such as groups/{id}/titles.
    final ref =
    _fs.collection(op['collection'] as String).doc(op['docId'] as String);
    if (op['op'] == 'delete') {
      await ref.delete();
    } else {
      final data = jsonDecode(op['data'] as String) as Map<String, dynamic>;
      await ref.set(data, SetOptions(merge: true));
    }
  }

  // ── pull (cloud → local) ──

  /// Adviser: consultations and action items are found by adviserUid.
  void _listenAdviserDocs(String uid) {
    for (final col in [
      FirestorePaths.consultations,
      FirestorePaths.actionItems,
    ]) {
      final q = _fs.collection(col).where('adviserUid', isEqualTo: uid);
      _adviserSubs.add(q.snapshots().listen(
            (snap) => _apply(col, _tableFor(col), snap),
        onError: (_) {},
      ));
    }
  }

  void _onGroups(List<Group> groups) {
    final ids = groups.map((g) => g.id).toList()..sort();
    final key = ids.join(',');
    if (key == _groupKey) return;
    _groupKey = key;
    _cancelAll(_groupSubs);
    if (ids.isEmpty) return;

    _listenTitles(ids);
    if (_user?.role == UserRole.student) _listenStudentDocs(ids);
  }

  /// Student: consultations and action items are found by group id.
  void _listenStudentDocs(List<String> ids) {
    for (final col in [
      FirestorePaths.consultations,
      FirestorePaths.actionItems,
    ]) {
      final q = _fs.collection(col).where('groupId', whereIn: ids);
      _groupSubs.add(q.snapshots().listen(
            (snap) => _apply(col, _tableFor(col), snap),
        onError: (_) {},
      ));
    }
  }

  /// Both roles: per-group subcollections (title ideas and milestones),
  /// one listener each per group.
  void _listenTitles(List<String> groupIds) {
    for (final id in groupIds) {
      for (final (sub, table) in [
        (FirestorePaths.titles, 'title_ideas'),
        (FirestorePaths.milestones, 'milestones'),
      ]) {
        final path = '${FirestorePaths.groups}/$id/$sub';
        _groupSubs.add(_fs.collection(path).snapshots().listen(
              (snap) => _apply(path, table, snap),
          onError: (_) {},
        ));
      }
    }
  }

  String _tableFor(String collection) =>
      collection == FirestorePaths.consultations
          ? 'consultations'
          : 'action_items';

  Map<String, Object?> _row(String table, Map<String, dynamic> d, String id) {
    switch (table) {
      case 'consultations':
        return Consultation.fromMap(d, id).toRow();
      case 'action_items':
        return ActionItem.fromMap(d, id).toRow();
      case 'milestones':
        return Milestone.fromMap(d, id).toRow();
      default:
        return TitleIdea.fromMap(d, id).toRow();
    }
  }

  Future<void> _apply(
      String collectionPath,
      String table,
      QuerySnapshot<Map<String, dynamic>> snap,
      ) async {
    if (_user == null) return;
    try {
      final db = await _db.instance;
      var changed = false;

      for (final change in snap.docChanges) {
        final doc = change.doc;
        // Our own unsynced edits win; they will be pushed shortly.
        if (await _db.hasPending(collectionPath, doc.id)) continue;

        if (change.type == DocumentChangeType.removed) {
          await db.delete(table, where: 'id = ?', whereArgs: [doc.id]);
          changed = true;
          continue;
        }

        final data = doc.data();
        if (data == null) continue;

        // Last-write-wins by updatedAt.
        final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
        final local = await db.query(table,
            columns: ['updatedAt'], where: 'id = ?', whereArgs: [doc.id]);
        if (local.isNotEmpty &&
            (local.first['updatedAt'] as int) > remoteUpdated) {
          continue;
        }

        await db.insert(table, _row(table, data, doc.id),
            conflictAlgorithm: ConflictAlgorithm.replace);
        changed = true;
      }

      if (changed) _db.notifyChanged();
    } catch (_) {
      // database closed (sign-out) or a transient error; the next snapshot retries
    }
  }
}