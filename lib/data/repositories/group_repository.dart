import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/limits.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/milestone.dart';

class GroupFailure implements Exception {
  GroupFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class GroupRepository {
  GroupRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.groups);

  /// Groups this user belongs to (student) or advises (adviser).
  Stream<List<Group>> watchMyGroups(AppUser user) {
    final Query<Map<String, dynamic>> query = user.role == UserRole.adviser
        ? _col.where('adviserUid', isEqualTo: user.uid)
        : _col.where('memberUids', arrayContains: user.uid);
    return query.snapshots().map(_toSortedList);
  }

  /// Groups that have no adviser yet (adviser "Requests" tab).
  Stream<List<Group>> watchOpenGroups() {
    return _col
        .where('adviserUid', isNull: true)
        .snapshots()
        .map(_toSortedList);
  }

  List<Group> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) {
    final groups = snap.docs.map((d) => Group.fromMap(d.data(), d.id)).toList();
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return groups;
  }

  Future<Group> createGroup({
    required AppUser student,
    required String name,
    required String section,
    required String thesisTitle,
    required List<String> members, // leader first
  }) async {
    final cleaned = members
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();

    if (cleaned.length < Limits.minGroupMembers ||
        cleaned.length > Limits.maxGroupMembers) {
      throw GroupFailure(
        'A group needs ${Limits.minGroupMembers} to ${Limits.maxGroupMembers} members.',
      );
    }
    final lower = cleaned.map((m) => m.toLowerCase()).toSet();
    if (lower.length != cleaned.length) {
      throw GroupFailure('Each member name must be different.');
    }
    if (student.role != UserRole.student) {
      throw GroupFailure('Only students can create groups.');
    }
    await _requireOnline();

    // Already in a group, as leader or as a member?
    final existing = await _col
        .where('memberUids', arrayContains: student.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw GroupFailure(
        'You already belong to a group. Each student can only be in one group.',
      );
    }

    // The document id is the leader's uid, so a second group for the same
    // leader is impossible, even with two quick taps or two devices.
    final ref = _col.doc(student.uid);
    final group = Group(
      id: ref.id,
      name: name.trim(),
      section: section.trim(),
      thesisTitle: thesisTitle.trim(),
      code: await _uniqueCode(),
      memberUids: [student.uid],
      memberNames: {student.uid: student.name},
      roster: cleaned,
      leaderUid: student.uid,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw GroupFailure('You have already created a group.');
      }
      tx.set(ref, group.toMap());
      for (final m in Milestone.defaults(group.id)) {
        tx.set(ref.collection(FirestorePaths.milestones).doc(m.id), m.toMap());
      }
    });
    return group;
  }

  /// Used at sign-up: checks that a teammate code exists before anything is saved.
  Future<void> verifyTeammateCode(String rawCode) async {
    await _requireOnline();
    final code = rawCode.trim().toUpperCase();
    final snap = await _col.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) {
      throw GroupFailure('No group found with that code.');
    }
  }

  /// Students only: join a teammate's group with its code.
  Future<void> joinByCode(AppUser user, String rawCode) async {
    if (user.role != UserRole.student) {
      throw GroupFailure('Only students join groups with a code.');
    }
    await _requireOnline();

    final code = rawCode.trim().toUpperCase();
    final snap = await _col.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) {
      throw GroupFailure('No group found with that code.');
    }
    final doc = snap.docs.first;

    final mine = await _col
        .where('memberUids', arrayContains: user.uid)
        .limit(1)
        .get();
    if (mine.docs.isNotEmpty) {
      throw GroupFailure(
        mine.docs.first.id == doc.id
            ? 'You are already in this group.'
            : 'You already belong to a group. Each student can only be in one group.',
      );
    }

    await doc.reference.update({
      'memberUids': FieldValue.arrayUnion([user.uid]),
      'memberNames.${user.uid}': user.name,
    });
  }

  /// Adviser accepts an open group. Runs in a transaction so the group can't
  /// be double-claimed and the adviser can't exceed the limit.
  Future<void> acceptGroup(AppUser adviser, String groupId) async {
    if (adviser.role != UserRole.adviser) {
      throw GroupFailure('Only advisers can accept groups.');
    }
    await _requireOnline();

    final groupRef = _col.doc(groupId);
    final userRef = _db.collection(FirestorePaths.users).doc(adviser.uid);

    await _db.runTransaction((tx) async {
      final groupSnap = await tx.get(groupRef);
      final userSnap = await tx.get(userRef);

      if (!groupSnap.exists) {
        throw GroupFailure('This group no longer exists.');
      }
      if (groupSnap.data()?['adviserUid'] != null) {
        throw GroupFailure('Another adviser already accepted this group.');
      }
      final count = (userSnap.data()?['adviserGroupCount'] as int?) ?? 0;
      if (count >= Limits.maxAdviserGroups) {
        throw GroupFailure(
          'You already advise ${Limits.maxAdviserGroups} groups, the maximum.',
        );
      }

      tx.update(groupRef, {
        'adviserUid': adviser.uid,
        'adviserName': adviser.name,
      });
      tx.update(userRef, {'adviserGroupCount': count + 1});
    });
  }

  // ---- helpers ----

  Future<void> _requireOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) {
      throw GroupFailure(
        'You\'re offline. Connect to the internet and try again.',
      );
    }
  }

  Future<String> _uniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
    final rnd = Random.secure();
    for (var i = 0; i < 5; i++) {
      final code = List.generate(
        6,
        (_) => chars[rnd.nextInt(chars.length)],
      ).join();
      final taken = await _col.where('code', isEqualTo: code).limit(1).get();
      if (taken.docs.isEmpty) return code;
    }
    throw GroupFailure('Could not generate a group code. Please try again.');
  }
}
