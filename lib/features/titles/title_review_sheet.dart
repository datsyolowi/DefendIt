import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/group.dart';
import '../../data/models/title_idea.dart';
import '../../data/repositories/title_repository.dart';
import '../auth/auth_provider.dart';
import 'title_status_chip.dart';

Future<void> showTitleReviewSheet(
    BuildContext context, {
      required Group group,
      required TitleIdea idea,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TitleReviewSheet(group: group, idea: idea),
  );
}

class _TitleReviewSheet extends StatefulWidget {
  const _TitleReviewSheet({required this.group, required this.idea});
  final Group group;
  final TitleIdea idea;

  @override
  State<_TitleReviewSheet> createState() => _TitleReviewSheetState();
}

class _TitleReviewSheetState extends State<_TitleReviewSheet> {
  static const _options = [
    TitleStatus.approved,
    TitleStatus.needsPolish,
    TitleStatus.rejected,
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _comment;
  TitleStatus? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comment = TextEditingController(text: widget.idea.comment);
    _status = widget.idea.isReviewed ? widget.idea.status : null;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_status == null) {
      setState(() => _error = 'Choose Approved, Needs polish, or Rejected.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<TitleRepository>().reviewTitle(
        adviser: context.read<AuthProvider>().profile!,
        group: widget.group,
        titleId: widget.idea.id,
        status: _status!,
        comment: _comment.text,
      );
      if (mounted) Navigator.pop(context);
    } on TitleFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save the review. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final needsComment = _status != null && _status != TitleStatus.approved;

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
              Text('Review title idea', style: text.headlineMedium),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.idea.title, style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(widget.idea.description, style: text.bodySmall),
                    if (widget.idea.purpose.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Purpose: ${widget.idea.purpose}',
                          style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Decision', style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _options)
                    ChoiceChip(
                      avatar: Icon(titleStatusIcon(s),
                          size: 18, color: titleStatusColor(s)),
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() {
                        _status = s;
                        _error = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comment,
                decoration: InputDecoration(
                  labelText:
                  needsComment ? 'Comment (required)' : 'Comment (optional)',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                maxLength: 400,
                validator: (v) => needsComment && (v ?? '').trim().isEmpty
                    ? 'Add a comment explaining what should change'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Save review', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}