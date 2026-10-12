import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/title_idea.dart';
import '../remote/network_guard.dart';

class TitleFailure implements Exception {
  TitleFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class TitleRepository {
  TitleRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _offline =
      'You\'re offline. Connect to the internet and try again.';

  CollectionReference<Map<String, dynamic>> _col(String groupId) => _db
      .collection(FirestorePaths.groups)
      .doc(groupId)
      .collection(FirestorePaths.titles);

  /// Oldest first, so the first title is the group's lead idea.
  Stream<List<TitleIdea>> watchTitles(String groupId) {
    return _col(groupId).snapshots().map((snap) {
      final list =
      snap.docs.map((d) => TitleIdea.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  void _requireMember(AppUser student, Group group) {
    if (student.role != UserRole.student ||
        !group.memberUids.contains(student.uid)) {
      throw TitleFailure('Only members of this group can manage its title ideas.');
    }
  }

  Future<void> addTitle({
    required AppUser student,
    required Group group,
    required String title,
    required String description,
    required String purpose,
  }) async {
    _requireMember(student, group);
    if (!await isOnline()) throw TitleFailure(_offline);

    final ref = _col(group.id).doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.set(TitleIdea(
      id: ref.id,
      groupId: group.id,
      title: title.trim(),
      description: description.trim(),
      purpose: purpose.trim(),
      status: TitleStatus.pending,
      createdByUid: student.uid,
      createdByName: student.name,
      createdAt: now,
      updatedAt: now,
    ).toMap());
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
    if (!await isOnline()) throw TitleFailure(_offline);

    final ref = _col(group.id).doc(titleId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw TitleFailure('This title idea no longer exists.');
      final current = TitleIdea.fromMap(snap.data()!, snap.id);
      if (!current.studentCanEdit) {
        throw TitleFailure(
            'Only pending or "needs polish" titles can be edited.');
      }
      tx.update(ref, {
        'title': title.trim(),
        'description': description.trim(),
        'purpose': purpose.trim(),
        'status': TitleStatus.pending.name,
        'comment': null,
        'reviewedByName': null,
        'reviewedAt': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<void> deleteTitle({
    required AppUser student,
    required Group group,
    required String titleId,
  }) async {
    _requireMember(student, group);
    if (!await isOnline()) throw TitleFailure(_offline);

    final ref = _col(group.id).doc(titleId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = TitleIdea.fromMap(snap.data()!, snap.id);
      if (!current.studentCanDelete) {
        throw TitleFailure('Approved titles can\'t be deleted.');
      }
      tx.delete(ref);
    });
  }

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
    if (!await isOnline()) throw TitleFailure(_offline);

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _col(group.id).doc(titleId).update({
        'status': status.name,
        'comment': clean.isEmpty ? null : clean,
        'reviewedByName': adviser.name,
        'reviewedAt': now,
        'updatedAt': now,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        throw TitleFailure('This title idea no longer exists.');
      }
      rethrow;
    }
  }
}