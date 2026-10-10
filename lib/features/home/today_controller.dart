import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/models/slot.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/slot_repository.dart';

class TodayController extends ChangeNotifier {
  TodayController({
    required this.user,
    required GroupRepository groupRepo,
    required SlotRepository slotRepo,
  }) : _slotRepo = slotRepo {
    _groupSub = groupRepo.watchMyGroups(user).listen(
      _onGroups,
      onError: (_) {
        _failed = true;
        _groupsLoaded = true;
        notifyListeners();
      },
    );
  }

  final AppUser user;
  final SlotRepository _slotRepo;

  StreamSubscription<List<Group>>? _groupSub;
  StreamSubscription<List<Slot>>? _slotSub;

  List<Group> _groups = const [];
  List<Slot> _slots = const [];
  bool _groupsLoaded = false;
  bool _slotsLoaded = false;
  bool _failed = false;
  String _slotKey = '\u0000'; // sentinel: forces the first subscription

  bool get isAdviser => user.role == UserRole.adviser;
  bool get loading => !_groupsLoaded || !_slotsLoaded;
  bool get failed => _failed;
  List<Group> get groups => _groups;

  /// Upcoming booked consultations that involve this user, soonest first.
  List<Slot> get upcomingBookings {
    final ids = _groups.map((g) => g.id).toSet();
    return _slots
        .where((s) =>
    s.isBooked &&
        s.isUpcoming &&
        (isAdviser || ids.contains(s.bookedGroupId)))
        .toList();
  }

  /// Adviser: their own open slots. Student: open slots they could book.
  int get openSlotCount {
    final now = DateTime.now();
    return _slots.where((s) => !s.isBooked && s.start.isAfter(now)).length;
  }

  bool get hasGroupAwaitingAdviser =>
      !isAdviser && _groups.any((g) => g.adviserUid == null);

  bool get hasAnyAdviser => _groups.any((g) => g.adviserUid != null);

  void _onGroups(List<Group> groups) {
    _groups = groups;
    _groupsLoaded = true;
    _failed = false;

    final uids = isAdviser
        ? [user.uid]
        : (groups
        .where((g) => g.adviserUid != null)
        .map((g) => g.adviserUid!)
        .toSet()
        .toList()
      ..sort());
    final key = uids.join(',');

    if (key != _slotKey) {
      _slotKey = key;
      _slotSub?.cancel();
      _slotSub = null;

      if (uids.isEmpty) {
        _slots = const [];
        _slotsLoaded = true;
      } else {
        _slotsLoaded = false;
        final stream = isAdviser
            ? _slotRepo.watchAdviserSlots(user.uid)
            : _slotRepo.watchSlotsForAdvisers(uids);
        _slotSub = stream.listen(
              (slots) {
            _slots = slots;
            _slotsLoaded = true;
            notifyListeners();
          },
          onError: (_) {
            _failed = true;
            _slotsLoaded = true;
            notifyListeners();
          },
        );
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _slotSub?.cancel();
    super.dispose();
  }
}