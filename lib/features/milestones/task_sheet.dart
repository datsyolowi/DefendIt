import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/group.dart';
import '../../data/models/milestone.dart';
import '../../data/models/milestone_task.dart';
import '../../data/repositories/milestone_repository.dart';
import '../auth/auth_provider.dart';

Future<void> showTaskSheet(
    BuildContext context, {
      required Group group,
      required Milestone milestone,
      MilestoneTask? existing,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _TaskSheet(group: group, milestone: milestone, existing: existing),
  );
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({
    required this.group,
    required this.milestone,
    this.existing,
  });

  final Group group;
  final Milestone milestone;
  final MilestoneTask? existing;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  String? _assignee; // null = whole group
  DateTime? _due;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title);
    _assignee = widget.existing?.assignee;
    _due = widget.existing?.due;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final initial = (_due != null && !_due!.isBefore(first))
        ? _due!
        : first.add(const Duration(days: 3));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() =>
      _due = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = context.read<AuthProvider>().profile!;
      final repo = context.read<MilestoneRepository>();
      if (_editing) {
        await repo.updateTask(
          actor: user,
          group: widget.group,
          task: widget.existing!,
          title: _title.text,
          assignee: _assignee,
          due: _due,
        );
      } else {
        await repo.addTask(
          actor: user,
          group: widget.group,
          milestone: widget.milestone,
          title: _title.text,
          assignee: _assignee,
          due: _due,
        );
      }
      if (mounted) Navigator.pop(context);
    } on MilestoneFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save the task. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final roster = widget.group.roster;
    final assigneeOptions = <String>[
      ...roster,
      if (_assignee != null && !roster.contains(_assignee)) _assignee!,
    ];

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
              Text(_editing ? 'Edit task' : 'New task',
                  style: text.headlineMedium),
              const SizedBox(height: 4),
              Text(widget.milestone.title, style: text.bodySmall),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                  hintText: 'e.g. Draft the survey questions',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                validator: (v) =>
                    Validators.text(v, label: 'Task', min: 3, max: 120),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: _assignee,
                decoration: const InputDecoration(labelText: 'Assigned to'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Whole group')),
                  for (final name in assigneeOptions)
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
              PrimaryButton(
                label: _editing ? 'Save changes' : 'Add task',
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