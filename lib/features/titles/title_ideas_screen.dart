import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/models/title_idea.dart';
import '../../data/repositories/title_repository.dart';
import '../auth/auth_provider.dart';
import 'title_form_sheet.dart';
import 'title_review_sheet.dart';
import 'title_status_chip.dart';

class TitleIdeasScreen extends StatefulWidget {
  const TitleIdeasScreen({super.key, required this.group});
  final Group group;

  @override
  State<TitleIdeasScreen> createState() => _TitleIdeasScreenState();
}

class _TitleIdeasScreenState extends State<TitleIdeasScreen> {
  late final AppUser _user;
  late final TitleRepository _repo;
  late final Stream<List<TitleIdea>> _stream;

  bool get _isStudent => _user.role == UserRole.student;
  bool get _canReview =>
      _user.role == UserRole.adviser && widget.group.adviserUid == _user.uid;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _repo = context.read<TitleRepository>();
    _stream = _repo.watchTitles(widget.group.id);
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } on TitleFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<void> _delete(TitleIdea idea) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this title idea?',
      message: '"${idea.title}" will be removed.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await _run(
          () => _repo.deleteTitle(
          student: _user, group: widget.group, titleId: idea.id),
      success: 'Title idea deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Title ideas')),
      floatingActionButton: _isStudent
          ? FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        onPressed: () => showTitleFormSheet(context, group: widget.group),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add title idea'),
      )
          : null,
      body: StreamBuilder<List<TitleIdea>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorView(
                message: 'Could not load title ideas. Check your connection.');
          }
          if (!snap.hasData) return const LoadingView();
          final ideas = snap.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _GroupHeader(group: widget.group),
              const SizedBox(height: 22),
              Text('Title ideas (${ideas.length})',
                  style: text.headlineMedium),
              const SizedBox(height: 12),
              if (ideas.isEmpty)
                SizedBox(
                  height: 240,
                  child: EmptyState(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'No title ideas yet',
                    message: _isStudent
                        ? 'Tap "Add title idea" to propose a thesis title. Your adviser will review each one.'
                        : 'This group has not proposed any titles yet.',
                  ),
                )
              else
                for (final idea in ideas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TitleCard(
                      idea: idea,
                      isStudent: _isStudent,
                      canReview: _canReview,
                      onEdit: () => showTitleFormSheet(context,
                          group: widget.group, existing: idea),
                      onDelete: () => _delete(idea),
                      onReview: () => showTitleReviewSheet(context,
                          group: widget.group, idea: idea),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final section = (group.section == null || group.section!.isEmpty)
        ? null
        : group.section;

    Widget row(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: text.headlineMedium),
            if (section != null) row(Icons.class_rounded, section),
            row(Icons.topic_rounded, group.thesisTitle),
            row(
              Icons.person_pin_rounded,
              group.adviserName == null
                  ? 'Awaiting adviser'
                  : 'Adviser: ${group.adviserName}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.idea,
    required this.isStudent,
    required this.canReview,
    required this.onEdit,
    required this.onDelete,
    required this.onReview,
  });

  final TitleIdea idea;
  final bool isStudent;
  final bool canReview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasComment = idea.comment != null && idea.comment!.isNotEmpty;
    final statusColor = titleStatusColor(idea.status);
    final showMenu =
        isStudent && (idea.studentCanEdit || idea.studentCanDelete);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Text(idea.title, style: text.titleMedium),
                  ),
                ),
                if (showMenu)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      if (idea.studentCanEdit)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (idea.studentCanDelete)
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text('Description',
                      style: text.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(idea.description, style: text.bodyMedium),
                  if (idea.purpose.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Purpose',
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(idea.purpose, style: text.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TitleStatusChip(status: idea.status),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('by ${idea.createdByName}',
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (hasComment) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idea.reviewedByName == null
                                ? 'Adviser comment'
                                : 'Comment from ${idea.reviewedByName}',
                            style: text.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(idea.comment!, style: text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                  if (isStudent && idea.status == TitleStatus.needsPolish) ...[
                    const SizedBox(height: 8),
                    Text('Edit this idea to resubmit it for review.',
                        style: text.bodySmall),
                  ],
                  if (canReview) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.rate_review_rounded, size: 18),
                      label: Text(
                          idea.isReviewed ? 'Update review' : 'Review'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}