import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/sync_chip.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/milestone_repository.dart';
import '../auth/auth_provider.dart';
import 'milestone_board_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final AppUser _user;
  late final Stream<List<Group>> _groups;
  late final Stream<Map<String, MilestoneProgress>> _progress;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _groups = context.read<GroupRepository>().watchMyGroups(_user);
    _progress = context.read<MilestoneRepository>().watchProgress();
  }

  Widget _frame(Widget body) => Scaffold(
    appBar: AppBar(
      title: const Text('Progress'),
      actions: const [SyncChip(), SizedBox(width: 12)],
    ),
    body: body,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Group>>(
      stream: _groups,
      builder: (context, snap) {
        if (snap.hasError) {
          return _frame(const ErrorView(
              message: 'Could not load your groups. Check your connection.'));
        }
        if (!snap.hasData) return _frame(const LoadingView());

        final groups = snap.data!;
        if (groups.isEmpty) {
          return _frame(EmptyState(
            icon: Icons.flag_outlined,
            title: 'No progress to track yet',
            message: _user.role == UserRole.adviser
                ? 'Accept a group from the Groups tab to follow its milestones.'
                : 'Create or join a thesis group to start tracking milestones.',
          ));
        }

        // A student belongs to exactly one group: show its board directly.
        if (_user.role == UserRole.student) {
          return _frame(MilestoneBoard(group: groups.first));
        }

        return _frame(
          StreamBuilder<Map<String, MilestoneProgress>>(
            stream: _progress,
            builder: (context, progressSnap) {
              final progress =
                  progressSnap.data ?? const <String, MilestoneProgress>{};
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _GroupProgressCard(
                  group: groups[i],
                  progress: progress[groups[i].id],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GroupProgressCard extends StatelessWidget {
  const _GroupProgressCard({required this.group, required this.progress});
  final Group group;
  final MilestoneProgress? progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = progress;
    final hasSection = group.section != null && group.section!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MilestoneBoardScreen(group: group),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(group.name, style: text.titleMedium)),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ],
              ),
              if (hasSection) ...[
                const SizedBox(height: 2),
                Text(group.section!, style: text.bodySmall),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p?.ratio ?? 0,
                  minHeight: 8,
                  backgroundColor: AppColors.indigoTint,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p == null
                    ? 'Milestones not synced yet'
                    : '${p.approved} of ${p.total} milestones approved',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}