import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/sync/sync_service.dart';
import '../theme/app_colors.dart';

/// Shows Offline / Syncing / Synced. Tap it to sync right now.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, this.onDark = false});

  /// Use on the dark Today header.
  final bool onDark;

  Future<void> _tap(BuildContext context) async {
    final sync = context.read<SyncService>();
    final messenger = ScaffoldMessenger.of(context);
    final hadPending = sync.pending > 0;
    await sync.syncNow();
    messenger.showSnackBar(SnackBar(
      content: Text(!sync.online
          ? 'You\'re offline. Changes will sync when you reconnect.'
          : hadPending
          ? 'Syncing your changes…'
          : 'Everything is up to date'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final String label;
    final Color color;
    final IconData icon;

    if (!sync.online) {
      label = sync.pending > 0 ? 'Offline · ${sync.pending} pending' : 'Offline';
      color = AppColors.amber;
      icon = Icons.cloud_off_rounded;
    } else if (sync.pending > 0 || sync.syncing) {
      label = 'Syncing…';
      color = AppColors.indigo;
      icon = Icons.sync_rounded;
    } else {
      label = 'Synced';
      color = AppColors.success;
      icon = Icons.cloud_done_rounded;
    }

    final fg = onDark ? Colors.white : color;
    final bg = onDark
        ? Colors.white.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.14);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _tap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}