import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sync_chip.dart';
import '../../data/models/group.dart';
import '../../data/models/milestone.dart';
import '../../data/models/milestone_task.dart';
import '../../data/repositories/milestone_repository.dart';
import 'milestone_detail_screen.dart';
import 'milestone_style.dart';

/// Full screen, opened from the adviser's list of groups.
class MilestoneBoardScreen extends StatelessWidget {
  const MilestoneBoardScreen({super.key, required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: const [SyncChip(), SizedBox(width: 12)],
      ),
      body: MilestoneBoard(group: group),
    );
  }
}

/// The milestone list itself, reused by the student's Progress tab.
class MilestoneBoard extends StatefulWidget {
  const MilestoneBoard({super.key, required this.group});
  final Group group;

  @override
  State<MilestoneBoard> createState() => _MilestoneBoardState();
}

class _MilestoneBoardState extends State<MilestoneBoard> {
  late final MilestoneRepository _repo;
  late final Stream<List<Milestone>> _milestones;
  late final Stream<Map<String, TaskCount>> _counts;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<MilestoneRepository>();
    _milestones = _repo.watchMilestones(widget.group.id);
    _counts = _repo.watchTaskCounts(widget.group.id);
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.ensureSeeded(widget.group);
    } on MilestoneFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not set up milestones.')));
    }
    if (mounted) setState(() => _seeding = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Milestone>>(
      stream: _milestones,
      builder: (context, snap) {
        if (snap.hasError) {
          return const ErrorView(message: 'Could not load milestones.');
        }
        if (!snap.hasData) return const LoadingView();

        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'Milestones not set up yet',
                    message:
                    'Create this group\'s milestone list. It needs an internet connection once.',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: PrimaryButton(
                        label: 'Set up milestones',
                        loading: _seeding,
                        onPressed: _seed),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<Map<String, TaskCount>>(
          stream: _counts,
          builder: (context, countSnap) {
            final counts = countSnap.data ?? const <String, TaskCount>{};

            var approved = 0;
            var tasksDone = 0;
            var tasksTotal = 0;
            var completion = 0.0;
            for (final m in items) {
              final c = counts[m.id];
              tasksDone += c?.done ?? 0;
              tasksTotal += c?.total ?? 0;
              if (m.status == MilestoneStatus.approved) {
                approved++;
                completion += 1;
              } else {
                completion += c?.ratio ?? 0;
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _ProgressCard(
                  ratio: completion / items.length,
                  approved: approved,
                  total: items.length,
                  tasksDone: tasksDone,
                  tasksTotal: tasksTotal,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SummaryCard(
                      index: i + 1,
                      milestone: items[i],
                      count: counts[items[i].id],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MilestoneDetailScreen(
                              group: widget.group, milestoneId: items[i].id),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.ratio,
    required this.approved,
    required this.total,
    required this.tasksDone,
    required this.tasksTotal,
  });

  final double ratio;
  final int approved;
  final int total;
  final int tasksDone;
  final int tasksTotal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Thesis progress', style: text.titleMedium)),
                Text('${(ratio * 100).round()}%',
                    style: text.headlineMedium
                        ?.copyWith(color: AppColors.indigo)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.indigoTint,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$approved of $total milestones approved · $tasksDone of $tasksTotal tasks done',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.index,
    required this.milestone,
    required this.count,
    required this.onTap,
  });

  final int index;
  final Milestone milestone;
  final TaskCount? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = milestone;
    final color = milestoneStatusColor(m.status);
    final overdue = m.isOverdue;
    final total = count?.total ?? 0;
    final done = count?.done ?? 0;
    final ratio = m.status == MilestoneStatus.approved
        ? 1.0
        : (count?.ratio ?? 0.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle),
                    child: m.status == MilestoneStatus.approved
                        ? Icon(Icons.check_rounded, size: 18, color: color)
                        : Text('$index',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(m.title, style: text.titleMedium)),
                  const SizedBox(width: 8),
                  MilestoneStatusChip(status: m.status),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: AppColors.indigoTint,
                  color: m.status == MilestoneStatus.approved
                      ? AppColors.success
                      : AppColors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded,
                      size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    total == 0 ? 'No tasks yet' : '$done of $total tasks done',
                    style: text.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.event_rounded,
                      size: 16,
                      color: overdue ? AppColors.error : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    m.due == null
                        ? 'No due date'
                        : '${overdue ? 'Overdue' : 'Due'} ${DateFormatters.shortDay(m.due!)}',
                    style: text.bodySmall?.copyWith(
                        color: overdue ? AppColors.error : AppColors.muted),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}