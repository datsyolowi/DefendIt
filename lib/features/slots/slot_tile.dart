import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../data/models/slot.dart';
import '../../data/repositories/slot_repository.dart';

/// Runs a slot action and reports success/failure in a snackbar.
Future<void> runSlotAction(
    BuildContext context,
    Future<void> Function() action, {
      String? success,
    }) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  } on SlotFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')));
  }
}

class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Slot slot;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = slot.isBooked ? AppColors.indigo : AppColors.success;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormatters.range(slot.start, slot.durationMins),
                        style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.durationMins} min${subtitle != null ? ' · $subtitle' : ''}',
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  slot.isBooked ? 'Booked' : 'Open',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent),
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slots (already sorted by start time) grouped under day headers.
class SlotDayList extends StatelessWidget {
  const SlotDayList({
    super.key,
    required this.slots,
    required this.itemBuilder,
    this.bottomPadding = 24,
  });

  final List<Slot> slots;
  final Widget Function(Slot slot) itemBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];
    DateTime? lastDay;

    for (final slot in slots) {
      final day = slot.start;
      if (lastDay == null || !DateFormatters.sameDay(lastDay, day)) {
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 0 : 16, 4, 8),
          child: Text(DateFormatters.dayHeader(day),
              style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.muted)),
        ));
        lastDay = day;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: itemBuilder(slot),
      ));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      children: children,
    );
  }
}