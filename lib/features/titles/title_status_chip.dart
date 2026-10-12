import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/title_idea.dart';

Color titleStatusColor(TitleStatus s) {
  switch (s) {
    case TitleStatus.pending:
      return AppColors.muted;
    case TitleStatus.approved:
      return AppColors.success;
    case TitleStatus.needsPolish:
      return const Color(0xFFB7791F);
    case TitleStatus.rejected:
      return AppColors.error;
  }
}

IconData titleStatusIcon(TitleStatus s) {
  switch (s) {
    case TitleStatus.pending:
      return Icons.hourglass_top_rounded;
    case TitleStatus.approved:
      return Icons.check_circle_rounded;
    case TitleStatus.needsPolish:
      return Icons.edit_note_rounded;
    case TitleStatus.rejected:
      return Icons.cancel_rounded;
  }
}

class TitleStatusChip extends StatelessWidget {
  const TitleStatusChip({super.key, required this.status});
  final TitleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = titleStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(titleStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 5),
          Text(status.label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}