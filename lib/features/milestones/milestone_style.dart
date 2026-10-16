import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/milestone.dart';

Color milestoneStatusColor(MilestoneStatus s) {
  switch (s) {
    case MilestoneStatus.notStarted:
      return AppColors.muted;
    case MilestoneStatus.inProgress:
      return AppColors.indigo;
    case MilestoneStatus.forReview:
      return const Color(0xFFB7791F);
    case MilestoneStatus.needsRevision:
      return AppColors.error;
    case MilestoneStatus.approved:
      return AppColors.success;
  }
}

String milestoneActionLabel(MilestoneStatus from, MilestoneStatus to) {
  if (to == MilestoneStatus.forReview) {
    return from == MilestoneStatus.needsRevision
        ? 'Resubmit for review'
        : 'Submit for review';
  }
  if (from == MilestoneStatus.notStarted) return 'Start';
  if (from == MilestoneStatus.forReview) return 'Withdraw submission';
  return 'Resume work';
}

class MilestoneStatusChip extends StatelessWidget {
  const MilestoneStatusChip({super.key, required this.status});
  final MilestoneStatus status;

  @override
  Widget build(BuildContext context) {
    final color = milestoneStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}