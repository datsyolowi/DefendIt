import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/slot_repository.dart';

Future<void> showAddSlotSheet(BuildContext context, AppUser adviser) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddSlotSheet(adviser: adviser),
  );
}

class _AddSlotSheet extends StatefulWidget {
  const _AddSlotSheet({required this.adviser});
  final AppUser adviser;

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 30;
  bool _busy = false;
  String? _error;

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SlotRepository>().createSlot(
        adviser: widget.adviser,
        start: _start,
        durationMins: _duration,
      );
      if (mounted) Navigator.pop(context);
    } on SlotFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not add the slot. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a consultation slot', style: text.headlineMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(DateFormatters.shortDay(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Duration', style: text.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [30, 45, 60])
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _duration == m,
                    onSelected: (_) => setState(() => _duration = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${DateFormatters.shortDay(_start)}, ${DateFormatters.range(_start, _duration)}',
              style: text.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Add slot', loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}