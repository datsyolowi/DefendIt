import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/group.dart';
import '../../data/models/title_idea.dart';
import '../../data/repositories/title_repository.dart';
import '../auth/auth_provider.dart';

Future<void> showTitleFormSheet(
    BuildContext context, {
      required Group group,
      TitleIdea? existing,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TitleFormSheet(group: group, existing: existing),
  );
}

class _TitleFormSheet extends StatefulWidget {
  const _TitleFormSheet({required this.group, this.existing});
  final Group group;
  final TitleIdea? existing;

  @override
  State<_TitleFormSheet> createState() => _TitleFormSheetState();
}

class _TitleFormSheetState extends State<_TitleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title);
    _desc = TextEditingController(text: widget.existing?.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = context.read<AuthProvider>().profile!;
      final repo = context.read<TitleRepository>();
      if (_editing) {
        await repo.updateTitle(
          student: user,
          group: widget.group,
          titleId: widget.existing!.id,
          title: _title.text,
          description: _desc.text,
        );
      } else {
        await repo.addTitle(
          student: user,
          group: widget.group,
          title: _title.text,
          description: _desc.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } on TitleFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save the title idea. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final comment = widget.existing?.comment;

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
              Text(_editing ? 'Revise title idea' : 'New title idea',
                  style: text.headlineMedium),
              if (_editing && comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.indigoTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adviser comment', style: text.bodySmall),
                      const SizedBox(height: 4),
                      Text(comment, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Proposed title'),
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
                validator: (v) =>
                    Validators.text(v, label: 'Title', min: 5, max: 150),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is the study about and why does it matter?',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                validator: (v) =>
                    Validators.text(v, label: 'Description', min: 10, max: 500),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _editing ? 'Resubmit for review' : 'Submit title idea',
                loading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}