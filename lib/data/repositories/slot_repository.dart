import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/date_formatters.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/slot.dart';
import '../remote/network_guard.dart';

class SlotFailure implements Exception {
  SlotFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SlotRepository {
  SlotRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.slots);

  static const _offline = 'You\'re offline. Connect to the internet and try again.';

  // ---- reads (live) ----

  Stream<List<Slot>> watchAdviserSlots(String adviserUid) {
    return _col
        .where('adviserUid', isEqualTo: adviserUid)
        .snapshots()
        .map(_toSortedList);
  }

  /// Slots from any of these advisers (a student's groups' advisers).
  /// Max 30 ids (Firestore whereIn limit), plenty for this app.
  Stream<List<Slot>> watchSlotsForAdvisers(List<String> adviserUids) {
    return _col
        .where('adviserUid', whereIn: adviserUids)
        .snapshots()
        .map(_toSortedList);
  }

  List<Slot> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) {
    final slots = snap.docs.map((d) => Slot.fromMap(d.data(), d.id)).toList();
    slots.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return slots;
  }

  // ---- create ----

  Future<void> createSlot({
    required AppUser adviser,
    required DateTime start,
    required int durationMins,
  }) async {
    if (adviser.role != UserRole.adviser) {
      throw SlotFailure('Only advisers can publish slots.');
    }
    if (!start.isAfter(DateTime.now())) {
      throw SlotFailure('Pick a time in the future.');
    }
    if (!await isOnline()) throw SlotFailure(_offline);

    final end = start.add(Duration(minutes: durationMins));

    // Reject overlaps with this adviser's own slots.
    final existing =
    await _col.where('adviserUid', isEqualTo: adviser.uid).get();
    for (final d in existing.docs) {
      final s = Slot.fromMap(d.data(), d.id);
      if (start.isBefore(s.end) && s.start.isBefore(end)) {
        throw SlotFailure(
            'This overlaps your slot on ${DateFormatters.shortDay(s.start)}, ${DateFormatters.range(s.start, s.durationMins)}.');
      }
    }

    final ref = _col.doc();
    await ref.set(Slot(
      id: ref.id,
      adviserUid: adviser.uid,
      adviserName: adviser.name,
      startsAt: start.millisecondsSinceEpoch,
      durationMins: durationMins,
      status: SlotStatus.open,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ).toMap());
  }

  // ---- book ----

  Future<void> bookSlot({
    required AppUser student,
    required Group group,
    required String slotId,
  }) async {
    if (student.role != UserRole.student) {
      throw SlotFailure('Only students can book slots.');
    }
    if (!group.memberUids.contains(student.uid)) {
      throw SlotFailure('You are not a member of this group.');
    }
    if (!await isOnline()) throw SlotFailure(_offline);

    final ref = _col.doc(slotId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw SlotFailure('This slot is no longer available.');
      }
      final slot = Slot.fromMap(snap.data()!, snap.id);
      if (slot.isBooked) {
        throw SlotFailure('Someone just booked this slot. Pick another one.');
      }
      if (!slot.start.isAfter(DateTime.now())) {
        throw SlotFailure('This slot has already started.');
      }
      if (slot.adviserUid != group.adviserUid) {
        throw SlotFailure('This slot is not from your group\'s adviser.');
      }
      tx.update(ref, {
        'status': SlotStatus.booked.name,
        'bookedGroupId': group.id,
        'bookedGroupName': group.name,
        'bookedByUid': student.uid,
        'bookedByName': student.name,
      });
    });
  }

  // ---- cancel booking (adviser, or a member of the booked group) ----

  Future<void> cancelBooking({
    required AppUser actor,
    required String slotId,
  }) async {
    if (!await isOnline()) throw SlotFailure(_offline);

    final ref = _col.doc(slotId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw SlotFailure('This slot no longer exists.');
      final slot = Slot.fromMap(snap.data()!, snap.id);
      if (!slot.isBooked) throw SlotFailure('This slot is not booked.');

      var allowed = slot.adviserUid == actor.uid;
      if (!allowed && slot.bookedGroupId != null) {
        final g = await tx.get(
            _db.collection(FirestorePaths.groups).doc(slot.bookedGroupId));
        final members = (g.data()?['memberUids'] as List?) ?? const [];
        allowed = members.contains(actor.uid);
      }
      if (!allowed) throw SlotFailure('You can\'t cancel this booking.');
      if (!slot.start.isAfter(DateTime.now())) {
        throw SlotFailure('This consultation has already started.');
      }

      tx.update(ref, {
        'status': SlotStatus.open.name,
        'bookedGroupId': null,
        'bookedGroupName': null,
        'bookedByUid': null,
        'bookedByName': null,
      });
    });
  }

  // ---- delete (adviser, open slots only) ----

  Future<void> deleteSlot({
    required AppUser adviser,
    required String slotId,
  }) async {
    if (!await isOnline()) throw SlotFailure(_offline);

    final ref = _col.doc(slotId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final slot = Slot.fromMap(snap.data()!, snap.id);
      if (slot.adviserUid != adviser.uid) {
        throw SlotFailure('You can only delete your own slots.');
      }
      if (slot.isBooked) {
        throw SlotFailure('This slot was just booked. Cancel the booking first.');
      }
      tx.delete(ref);
    });
  }
}