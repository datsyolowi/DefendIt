import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/constants/firestore_paths.dart';
import '../models/app_user.dart';
import '../models/group.dart';

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

  /// Live list of the groups this user belongs to (student) or advises (adviser).
  Stream<List<Group>> watchMyGroups(AppUser user) {
    final Query<Map<String, dynamic>> query = user.role == UserRole.adviser
        ? _col.where('adviserUid', isEqualTo: user.uid)
        : _col.where('memberUids', arrayContains: user.uid);

    return query.snapshots().map((snap) {
      final groups =
      snap.docs.map((d) => Group.fromMap(d.data(), d.id)).toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  Future<Group> createGroup({
    required AppUser student,
    required String name,
    required String thesisTitle,
  }) async {
    await _requireOnline();
    final ref = _col.doc();
    final group = Group(
      id: ref.id,
      name: name.trim(),
      thesisTitle: thesisTitle.trim(),
      code: await _uniqueCode(),
      memberUids: [student.uid],
      memberNames: {student.uid: student.name},
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.set(group.toMap());
    return group;
  }

  Future<void> joinByCode(AppUser user, String rawCode) async {
    await _requireOnline();
    final code = rawCode.trim().toUpperCase();
    final snap = await _col.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) {
      throw GroupFailure('No group found with that code.');
    }

    final doc = snap.docs.first;
    final group = Group.fromMap(doc.data(), doc.id);

    if (user.role == UserRole.adviser) {
      if (group.adviserUid == user.uid) {
        throw GroupFailure('You are already this group\'s adviser.');
      }
      if (group.adviserUid != null) {
        throw GroupFailure('This group already has an adviser.');
      }
      await doc.reference.update({
        'adviserUid': user.uid,
        'adviserName': user.name,
      });
    } else {
      if (group.memberUids.contains(user.uid)) {
        throw GroupFailure('You are already in this group.');
      }
      await doc.reference.update({
        'memberUids': FieldValue.arrayUnion([user.uid]),
        'memberNames.${user.uid}': user.name,
      });
    }
  }

  // ---- helpers ----

  Future<void> _requireOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) {
      throw GroupFailure('You\'re offline. Connect to the internet and try again.');
    }
  }

  Future<String> _uniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
    final rnd = Random.secure();
    for (var i = 0; i < 5; i++) {
      final code =
      List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
      final taken = await _col.where('code', isEqualTo: code).limit(1).get();
      if (taken.docs.isEmpty) return code;
    }
    throw GroupFailure('Could not generate a group code. Please try again.');
  }
}