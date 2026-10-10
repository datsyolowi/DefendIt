import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';

Future<void> showActionItemSheet(BuildContext context, Consultation c) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ActionItemSheet(consultation: c),
  );
}

class _ActionItemSheet extends StatefulWidget {
  const _ActionItemSheet({required this.consultation});
  final Consultation consultation;

  @override
  State<_ActionItemSheet> createState() => _ActionItemSheetState();
}

class _ActionItemSheetState extends State<_ActionItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String? _assignee; // null = whole group
  DateTime? _due;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _due = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ConsultationRepository>().addItem(
        widget.consultation,
        title: _title.text,
        assignee: _assignee,
        due: _due,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'Could not add the action item.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final roster = widget.consultation.roster;

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
              Text('New action item', style: text.headlineMedium),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'What needs to be done?'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                validator: (v) =>
                    Validators.text(v, label: 'Action item', min: 3, max: 120),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: _assignee,
                decoration: const InputDecoration(labelText: 'Assigned to'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Whole group')),
                  for (final name in roster)
                    DropdownMenuItem<String?>(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _assignee = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDue,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(_due == null
                          ? 'Due date (optional)'
                          : DateFormatters.shortDay(_due!)),
                    ),
                  ),
                  if (_due != null)
                    IconButton(
                      tooltip: 'Clear due date',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _due = null),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Add action item', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}