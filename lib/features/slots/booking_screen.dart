import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/models/slot.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/slot_repository.dart';
import '../auth/auth_provider.dart';
import 'slot_tile.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final AppUser _user;
  StreamSubscription<List<Group>>? _sub;

  bool _loaded = false;
  bool _failed = false;
  bool _hasAnyGroup = false;
  List<Group> _groups = const []; // only groups that have an adviser
  Stream<List<Slot>>? _slots;
  String _adviserKey = '';

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    final slotRepo = context.read<SlotRepository>();

    _sub = context.read<GroupRepository>().watchMyGroups(_user).listen(
          (all) {
        final withAdviser = all.where((g) => g.adviserUid != null).toList();
        final uids =
        withAdviser.map((g) => g.adviserUid!).toSet().toList()..sort();
        final key = uids.join(',');
        setState(() {
          _loaded = true;
          _failed = false;
          _hasAnyGroup = all.isNotEmpty;
          _groups = withAdviser;
          if (key != _adviserKey) {
            _adviserKey = key;
            _slots = uids.isEmpty ? null : slotRepo.watchSlotsForAdvisers(uids);
          }
        });
      },
      onError: (_) => setState(() {
        _loaded = true;
        _failed = true;
      }),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _book(Slot slot) async {
    final candidates =
    _groups.where((g) => g.adviserUid == slot.adviserUid).toList();
    if (candidates.isEmpty) return;

    Group? group;
    if (candidates.length == 1) {
      group = candidates.first;
    } else {
      group = await showDialog<Group>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Book for which group?'),
          children: [
            for (final g in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, g),
                child: Text(g.name),
              ),
          ],
        ),
      );
    }
    if (group == null || !mounted) return;

    final ok = await confirmDialog(
      context,
      title: 'Book this slot?',
      message:
      '${DateFormatters.shortDay(slot.start)}, ${DateFormatters.range(slot.start, slot.durationMins)} with ${slot.adviserName} for ${group.name}.',
      confirmLabel: 'Book',
    );
    if (!ok || !mounted) return;

    await runSlotAction(
      context,
          () => context
          .read<SlotRepository>()
          .bookSlot(student: _user, group: group!, slotId: slot.id),
      success: 'Consultation booked',
    );
  }

  Future<void> _cancel(Slot slot) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this booking?',
      message: 'The slot goes back to ${slot.adviserName}\'s open times.',
      confirmLabel: 'Cancel booking',
    );
    if (!ok || !mounted) return;
    await runSlotAction(
      context,
          () => context
          .read<SlotRepository>()
          .cancelBooking(actor: _user, slotId: slot.id),
      success: 'Booking cancelled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = const Text('Schedule');

    if (!_loaded) {
      return Scaffold(appBar: AppBar(title: title), body: const LoadingView());
    }
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const ErrorView(
            message: 'Could not load your groups. Check your connection.'),
      );
    }
    if (!_hasAnyGroup) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const EmptyState(
          icon: Icons.groups_rounded,
          title: 'Join a group first',
          message: 'Create or join a thesis group in the Groups tab to book consultations.',
        ),
      );
    }
    if (_slots == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const EmptyState(
          icon: Icons.hourglass_top_rounded,
          title: 'Waiting for an adviser',
          message:
          'Once an adviser accepts your group, their open consultation slots appear here.',
        ),
      );
    }

    final myGroupIds = _groups.map((g) => g.id).toSet();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          bottom: const TabBar(
            tabs: [Tab(text: 'Available'), Tab(text: 'My bookings')],
          ),
        ),
        body: StreamBuilder<List<Slot>>(
          stream: _slots,
          builder: (context, snap) {
            if (snap.hasError) {
              return const ErrorView(
                  message: 'Could not load slots. Check your connection.');
            }
            if (!snap.hasData) return const LoadingView();

            final now = DateTime.now();
            final available = snap.data!
                .where((s) => !s.isBooked && s.start.isAfter(now))
                .toList();
            final mine = snap.data!
                .where((s) =>
            s.isBooked &&
                s.isUpcoming &&
                myGroupIds.contains(s.bookedGroupId))
                .toList();

            return TabBarView(
              children: [
                available.isEmpty
                    ? const EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No open slots',
                  message:
                  'Your adviser has not published any open times yet. Check back soon.',
                )
                    : SlotDayList(
                  slots: available,
                  itemBuilder: (slot) => SlotTile(
                    slot: slot,
                    subtitle: 'with ${slot.adviserName}',
                    trailing: TextButton(
                      onPressed: () => _book(slot),
                      child: const Text('Book'),
                    ),
                  ),
                ),
                mine.isEmpty
                    ? const EmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'No bookings yet',
                  message: 'Book a slot from the Available tab.',
                )
                    : SlotDayList(
                  slots: mine,
                  itemBuilder: (slot) => SlotTile(
                    slot: slot,
                    subtitle: '${slot.bookedGroupName} · ${slot.adviserName}',
                    trailing: IconButton(
                      tooltip: 'Cancel booking',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _cancel(slot),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}