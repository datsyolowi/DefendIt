import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/consultation_repository.dart';
import '../consultations/consultation_notes_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/slot.dart';
import '../../data/repositories/slot_repository.dart';
import '../auth/auth_provider.dart';
import 'add_slot_sheet.dart';
import 'slot_tile.dart';

class AdviserAvailabilityScreen extends StatefulWidget {
  const AdviserAvailabilityScreen({super.key});

  @override
  State<AdviserAvailabilityScreen> createState() =>
      _AdviserAvailabilityScreenState();
}

class _AdviserAvailabilityScreenState extends State<AdviserAvailabilityScreen> {
  late final AppUser _user;
  late final Stream<List<Slot>> _stream;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _stream = context.read<SlotRepository>().watchAdviserSlots(_user.uid);
  }

  Future<void> _cancelBooking(Slot slot) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this booking?',
      message:
      '${slot.bookedGroupName} will lose this consultation and the slot becomes open again.',
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

  Future<void> _delete(Slot slot) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this slot?',
      message: 'It will no longer be available to students.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await runSlotAction(
      context,
          () => context
          .read<SlotRepository>()
          .deleteSlot(adviser: _user, slotId: slot.id),
      success: 'Slot deleted',
    );
  }

  Future<void> _openConsultation(Slot slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final c = await context.read<ConsultationRepository>().openForAdviser(slot);
      if (!mounted) return;
      nav.push(MaterialPageRoute(
          builder: (_) => ConsultationScreen(consultationId: c.id)));
    } on ConsultationFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the consultation.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        onPressed: () => showAddSlotSheet(context, _user),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add slot'),
      ),
      body: StreamBuilder<List<Slot>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorView(
                message: 'Could not load your slots. Check your connection.');
          }
          if (!snap.hasData) return const LoadingView();

          final slots = snap.data!.where((s) => s.isUpcoming).toList();
          if (slots.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available_rounded,
              title: 'No upcoming slots',
              message:
              'Publish times when you\'re free. Students in your groups can book them.',
            );
          }

          return SlotDayList(
            slots: slots,
            bottomPadding: 96,
            itemBuilder: (slot) => SlotTile(
              slot: slot,
              subtitle: slot.isBooked
                  ? '${slot.bookedGroupName} (${slot.bookedByName})'
                  : null,
              onTap: slot.isBooked ? () => _openConsultation(slot) : null,
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) =>
                v == 'cancel' ? _cancelBooking(slot) : _delete(slot),
                itemBuilder: (_) => [
                  if (slot.isBooked)
                    const PopupMenuItem(
                        value: 'cancel', child: Text('Cancel booking'))
                  else
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete slot')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}