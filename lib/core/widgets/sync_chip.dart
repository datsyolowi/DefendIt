import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/sync/sync_service.dart';
import '../theme/app_colors.dart';

class SyncChip extends StatelessWidget {
  const SyncChip({super.key});

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}