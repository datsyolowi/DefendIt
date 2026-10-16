import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sync_chip.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/models/milestone.dart';
import '../../data/models/milestone_task.dart';
import '../../data/repositories/milestone_repository.dart';
import '../auth/auth_provider.dart';
import 'milestone_style.dart';
import 'task_sheet.dart';

class MilestoneDetailScreen extends StatefulWidget {
  const MilestoneDetailScreen({
    super.key,
    required this.group,
    required this.milestoneId,
  });

  final Group group;
  final String milestoneId;

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  late final AppUser _user;
  late final MilestoneRepository _repo;
  late final Stream<Milestone?> _milestone;
  late final Stream<List<MilestoneTask>> _tasks;

  Group get _group => widget.group;
  bool get _isAdviser =>
      _user.role == UserRole.adviser && _group.adviserUid == _user.uid;
  bool get _isMember =>
      _user.role == UserRole.student && _group.memberUids.contains(_user.uid);

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _repo = context.read<MilestoneRepository>();
    _milestone = _repo.watchMilestone(widget.milestoneId);
    _tasks = _repo.watchTasks(widget.milestoneId);
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } on MilestoneFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<void> _move(Milestone m, MilestoneStatus to) => _run(() => _repo
      .changeStatus(actor: _user, group: _group, milestone: m, to: to));

  Future<void> _approve(Milestone m) async {
    final ok = await confirmDialog(
      context,
      title: 'Approve this milestone?',
      message: '"${m.title}" will be marked approved for ${_group.name}.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    await _run(
          () => _repo.changeStatus(
          actor: _user,
          group: _group,
          milestone: m,
          to: MilestoneStatus.approved),
      success: 'Milestone approved',
    );
  }

  Future<void> _sendBack(Milestone m) async {
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RevisionSheet(title: m.title),
    );
    if (comment == null || !mounted) return;
    await _run(
          () => _repo.changeStatus(
        actor: _user,
        group: _group,
        milestone: m,
        to: MilestoneStatus.needsRevision,
        comment: comment,
      ),
      success: 'Sent back for revision',
    );
  }

  Future<void> _pickDue(Milestone m) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final initial = (m.due != null && !m.due!.isBefore(first))
        ? m.due!
        : first.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    await _run(
          () => _repo.setDue(
        adviser: _user,
        group: _group,
        milestone: m,
        due: DateTime(picked.year, picked.month, picked.day, 23, 59),
      ),
      success: 'Due date set',
    );
  }

  Future<void> _clearDue(Milestone m) => _run(() => _repo.setDue(
      adviser: _user, group: _group, milestone: m, due: null));

  Future<void> _toggle(MilestoneTask t, bool done) => _run(() => _repo
      .setTaskDone(actor: _user, group: _group, task: t, done: done));

  Future<void> _deleteTask(MilestoneTask t) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this task?',
      message: '"${t.title}" will be removed for the whole group.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await _run(
          () => _repo.deleteTask(actor: _user, group: _group, task: t),
      success: 'Task deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Milestone'),
        actions: const [SyncChip(), SizedBox(width: 12)],
      ),
      body: StreamBuilder<Milestone?>(
        stream: _milestone,
        builder: (context, ms) {
          if (ms.hasError) {
            return const ErrorView(message: 'Could not load this milestone.');
          }
          if (!ms.hasData && ms.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final m = ms.data;
          if (m == null) {
            return const ErrorView(
                message: 'This milestone is not on this device yet.');
          }

          return StreamBuilder<List<MilestoneTask>>(
            stream: _tasks,
            builder: (context, ts) {
              final tasks = ts.data ?? const <MilestoneTask>[];
              final editable = _isMember && m.status.allowsTaskEdits;
              final text = Theme.of(context).textTheme;
              final done = tasks.where((t) => t.done).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _header(m, tasks),
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Team workload', style: text.headlineMedium),
                    const SizedBox(height: 10),
                    _workload(tasks),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Tasks (${done}/${tasks.length})',
                            style: text.headlineMedium),
                      ),
                      if (editable)
                        FilledButton.icon(
                          onPressed: () => showTaskSheet(context,
                              group: _group, milestone: m),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add task'),
                        ),
                    ],
                  ),
                  if (_isMember && !m.status.allowsTaskEdits)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        m.status == MilestoneStatus.approved
                            ? 'This milestone is approved, so its tasks are locked.'
                            : 'Tasks are locked while your adviser reviews this milestone.',
                        style: text.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _isMember
                            ? 'Break this milestone into tasks, assign each to a teammate, and tick them off as you finish.'
                            : 'The group has not added tasks for this milestone yet.',
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    )
                  else
                    for (final t in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _taskTile(m, t, editable),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ───────── header with progress and actions ─────────

  Widget _header(Milestone m, List<MilestoneTask> tasks) {
    final text = Theme.of(context).textTheme;
    final color = milestoneStatusColor(m.status);
    final done = tasks.where((t) => t.done).length;
    final total = tasks.length;
    final ratio = m.status == MilestoneStatus.approved
        ? 1.0
        : (total == 0 ? 0.0 : done / total);
    final ready = total > 0 && done == total;
    final overdue = m.isOverdue;
    final hasComment = m.comment != null && m.comment!.isNotEmpty;

    final studentMoves =
    _isMember ? m.status.studentNext : const <MilestoneStatus>[];
    final adviserMoves =
    _isAdviser ? m.status.adviserNext : const <MilestoneStatus>[];
    final needsReadyHint =
        studentMoves.contains(MilestoneStatus.forReview) && !ready;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(m.title, style: text.headlineMedium)),
                const SizedBox(width: 8),
                MilestoneStatusChip(status: m.status),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.indigoTint,
                color: m.status == MilestoneStatus.approved
                    ? AppColors.success
                    : AppColors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'No tasks yet'
                  : '$done of $total tasks done (${(ratio * 100).round()}%)',
              style: text.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 18,
                    color: overdue ? AppColors.error : AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m.due == null
                        ? 'No due date'
                        : '${overdue ? 'Overdue' : 'Due'} ${DateFormatters.shortDay(m.due!)}',
                    style: text.bodySmall?.copyWith(
                        color: overdue ? AppColors.error : AppColors.muted),
                  ),
                ),
                if (_isAdviser)
                  TextButton(
                    onPressed: () => _pickDue(m),
                    child: Text(m.due == null ? 'Set date' : 'Change'),
                  ),
                if (_isAdviser && m.due != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => _clearDue(m),
                  ),
              ],
            ),
            if (hasComment) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adviser feedback',
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(m.comment!, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
            if (_isMember && m.status == MilestoneStatus.forReview)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Submitted. Waiting for your adviser to review.',
                    style: text.bodySmall),
              ),
            if (_isAdviser && m.status != MilestoneStatus.forReview &&
                m.status != MilestoneStatus.approved)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    'The group is still working on this. You can review it once they submit.',
                    style: text.bodySmall),
              ),
            if (studentMoves.isNotEmpty || adviserMoves.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final to in studentMoves)
                    to == MilestoneStatus.forReview
                        ? FilledButton(
                        onPressed: ready ? () => _move(m, to) : null,
                        child: Text(milestoneActionLabel(m.status, to)))
                        : OutlinedButton(
                        onPressed: () => _move(m, to),
                        child: Text(milestoneActionLabel(m.status, to))),
                  if (adviserMoves.contains(MilestoneStatus.approved))
                    FilledButton(
                        onPressed: () => _approve(m),
                        child: const Text('Approve')),
                  if (adviserMoves.contains(MilestoneStatus.needsRevision))
                    OutlinedButton(
                        onPressed: () => _sendBack(m),
                        child: const Text('Request revision')),
                ],
              ),
            ],
            if (needsReadyHint)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  total == 0
                      ? 'Add at least one task, then finish them all to submit.'
                      : 'Finish the remaining ${total - done} task${total - done == 1 ? '' : 's'} to submit.',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────── per-member workload ─────────

  Widget _workload(List<MilestoneTask> tasks) {
    final text = Theme.of(context).textTheme;
    final names = <String?>[
      ..._group.roster,
      if (tasks.any((t) => t.assignee == null)) null,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < names.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _WorkloadRow(
                label: names[i] == null
                    ? 'Whole group'
                    : (i == 0 ? '${names[i]} (leader)' : names[i]!),
                done: tasks
                    .where((t) => t.assignee == names[i] && t.done)
                    .length,
                total: tasks.where((t) => t.assignee == names[i]).length,
                text: text,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────── a task ─────────

  Widget _taskTile(Milestone m, MilestoneTask t, bool editable) {
    final text = Theme.of(context).textTheme;
    final overdue = t.isOverdue;

    final details = <String>[
      t.assignee ?? 'Whole group',
      if (t.due != null)
        '${overdue ? 'Overdue' : 'Due'} ${DateFormatters.shortDay(t.due!)}',
    ].join(' · ');

    final trail = t.done
        ? 'Done by ${t.doneByName ?? 'a member'}${t.doneAt == null ? '' : ' on ${DateFormatters.shortDay(DateTime.fromMillisecondsSinceEpoch(t.doneAt!))}'}'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          children: [
            Checkbox(
              value: t.done,
              activeColor: AppColors.success,
              onChanged: editable ? (v) => _toggle(t, v ?? false) : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: text.titleMedium?.copyWith(
                      decoration: t.done ? TextDecoration.lineThrough : null,
                      color: t.done ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(details,
                      style: text.bodySmall?.copyWith(
                          color: overdue ? AppColors.error : AppColors.muted)),
                  if (trail != null)
                    Text(trail,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.success)),
                ],
              ),
            ),
            if (editable)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) => v == 'edit'
                    ? showTaskSheet(context,
                    group: _group, milestone: m, existing: t)
                    : _deleteTask(t),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _WorkloadRow extends StatelessWidget {
  const _WorkloadRow({
    required this.label,
    required this.done,
    required this.total,
    required this.text,
  });

  final String label;
  final int done;
  final int total;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: text.bodyMedium, overflow: TextOverflow.ellipsis)),
            Text(total == 0 ? 'No tasks' : '$done/$total done',
                style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            backgroundColor: AppColors.indigoTint,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _RevisionSheet extends StatefulWidget {
  const _RevisionSheet({required this.title});
  final String title;

  @override
  State<_RevisionSheet> createState() => _RevisionSheetState();
}

class _RevisionSheetState extends State<_RevisionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request revision', style: text.headlineMedium),
              const SizedBox(height: 4),
              Text(widget.title, style: text.bodySmall),
              const SizedBox(height: 18),
              TextFormField(
                controller: _comment,
                decoration: const InputDecoration(
                  labelText: 'What should the group revise?',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                maxLength: 400,
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Add a short comment explaining what to revise'
                    : null,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Send back',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, _comment.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}