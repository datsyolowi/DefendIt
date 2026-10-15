import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sync_chip.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/models/milestone.dart';
import '../../data/repositories/milestone_repository.dart';
import '../auth/auth_provider.dart';

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
  late final AppUser _user;
  late final MilestoneRepository _repo;
  late final Stream<List<Milestone>> _stream;
  bool _seeding = false;

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
    _stream = _repo.watchMilestones(widget.group.id);
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

  Future<void> _seed() async {
    setState(() => _seeding = true);
    await _run(() => _repo.ensureSeeded(_group));
    if (mounted) setState(() => _seeding = false);
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Milestone>>(
      stream: _stream,
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

        final approved =
            items.where((m) => m.status == MilestoneStatus.approved).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProgressCard(approved: approved, total: items.length),
            const SizedBox(height: 16),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MilestoneCard(
                  index: i + 1,
                  milestone: items[i],
                  isAdviser: _isAdviser,
                  isMember: _isMember,
                  onMove: (to) => _move(items[i], to),
                  onApprove: () => _approve(items[i]),
                  onSendBack: () => _sendBack(items[i]),
                  onPickDue: () => _pickDue(items[i]),
                  onClearDue: () => _clearDue(items[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

Color _statusColor(MilestoneStatus s) {
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

String _actionLabel(MilestoneStatus from, MilestoneStatus to) {
  if (to == MilestoneStatus.forReview) {
    return from == MilestoneStatus.needsRevision
        ? 'Resubmit for review'
        : 'Submit for review';
  }
  if (from == MilestoneStatus.notStarted) return 'Start';
  if (from == MilestoneStatus.forReview) return 'Withdraw submission';
  return 'Resume work';
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.approved, required this.total});
  final int approved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : approved / total;

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
            Text('$approved of $total milestones approved',
                style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.index,
    required this.milestone,
    required this.isAdviser,
    required this.isMember,
    required this.onMove,
    required this.onApprove,
    required this.onSendBack,
    required this.onPickDue,
    required this.onClearDue,
  });

  final int index;
  final Milestone milestone;
  final bool isAdviser;
  final bool isMember;
  final ValueChanged<MilestoneStatus> onMove;
  final VoidCallback onApprove;
  final VoidCallback onSendBack;
  final VoidCallback onPickDue;
  final VoidCallback onClearDue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = milestone;
    final color = _statusColor(m.status);
    final overdue = m.isOverdue;
    final hasComment = m.comment != null && m.comment!.isNotEmpty;

    final studentMoves =
    isMember ? m.status.studentNext : const <MilestoneStatus>[];
    final adviserMoves =
    isAdviser ? m.status.adviserNext : const <MilestoneStatus>[];
    final hasActions = studentMoves.isNotEmpty || adviserMoves.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(m.status.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 18, color: overdue ? AppColors.error : AppColors.muted),
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
                if (isAdviser)
                  TextButton(
                    onPressed: onPickDue,
                    child: Text(m.due == null ? 'Set date' : 'Change'),
                  ),
                if (isAdviser && m.due != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClearDue,
                  ),
              ],
            ),
            if (hasComment)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
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
              ),
            if (isMember && m.status == MilestoneStatus.forReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Waiting for your adviser to review.',
                    style: text.bodySmall),
              ),
            if (hasActions)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final to in studentMoves)
                      to == MilestoneStatus.forReview
                          ? FilledButton(
                          onPressed: () => onMove(to),
                          child: Text(_actionLabel(m.status, to)))
                          : OutlinedButton(
                          onPressed: () => onMove(to),
                          child: Text(_actionLabel(m.status, to))),
                    if (adviserMoves.contains(MilestoneStatus.approved))
                      FilledButton(
                          onPressed: onApprove, child: const Text('Approve')),
                    if (adviserMoves.contains(MilestoneStatus.needsRevision))
                      OutlinedButton(
                          onPressed: onSendBack,
                          child: const Text('Request revision')),
                  ],
                ),
              ),
          ],
        ),
      ),
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