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
import '../../data/models/action_item.dart';
import '../../data/models/app_user.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import '../auth/auth_provider.dart';
import 'action_items_screen.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key, required this.consultationId});
  final String consultationId;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  late final AppUser _user;
  late final ConsultationRepository _repo;
  late final Stream<Consultation?> _consultation;
  late final Stream<List<ActionItem>> _items;
  final _notes = TextEditingController();
  bool _notesReady = false;
  bool _saving = false;

  bool get _isAdviser => _user.role == UserRole.adviser;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _repo = context.read<ConsultationRepository>();
    _consultation = _repo.watchConsultation(widget.consultationId);
    _items = _repo.watchItems(widget.consultationId);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _onNotesChanged() => setState(() {});

  Future<void> _saveNotes(Consultation c) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.saveNotes(c, _notes.text);
      messenger.showSnackBar(const SnackBar(content: Text('Notes saved')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the notes.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        actions: const [SyncChip(), SizedBox(width: 12)],
      ),
      body: StreamBuilder<Consultation?>(
        stream: _consultation,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorView(message: 'Could not open this consultation.');
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const LoadingView();
          }
          final c = snap.data;
          if (c == null) {
            return const EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Consultation not found',
              message: 'It may not have synced to this device yet.',
            );
          }

          if (!_notesReady) {
            _notes.text = c.notes;
            _notes.addListener(_onNotesChanged);
            _notesReady = true;
          }
          final dirty = _notes.text.trim() != c.notes.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _HeaderCard(c: c),
              const SizedBox(height: 24),
              Text('Meeting notes', style: text.headlineMedium),
              const SizedBox(height: 12),
              if (_isAdviser) ...[
                TextField(
                  controller: _notes,
                  minLines: 5,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'What was discussed and decided?'),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Save notes',
                  loading: _saving,
                  onPressed: dirty ? () => _saveNotes(c) : null,
                ),
              ] else
                _ReadOnlyNotes(notes: c.notes),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                      child: Text('Action items', style: text.headlineMedium)),
                  if (_isAdviser)
                    TextButton.icon(
                      onPressed: () => showActionItemSheet(context, c),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _ItemsSection(
                  stream: _items, isAdviser: _isAdviser, repo: _repo),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.c});
  final Consultation c;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.groupName, style: text.headlineMedium),
            const SizedBox(height: 8),
            _line(context, Icons.event_rounded,
                '${DateFormatters.shortDay(c.start)} · ${DateFormatters.range(c.start, c.durationMins)}'),
            const SizedBox(height: 6),
            _line(context, Icons.person_pin_rounded, 'Adviser: ${c.adviserName}'),
            if (c.roster.isNotEmpty) ...[
              const SizedBox(height: 6),
              _line(context, Icons.groups_rounded, c.roster.join(', ')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
    ],
  );
}

class _ReadOnlyNotes extends StatelessWidget {
  const _ReadOnlyNotes({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        notes.isEmpty ? 'Your adviser has not added notes yet.' : notes,
        style: notes.isEmpty
            ? text.bodyMedium?.copyWith(color: AppColors.muted)
            : text.bodyMedium,
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.stream,
    required this.isAdviser,
    required this.repo,
  });

  final Stream<List<ActionItem>> stream;
  final bool isAdviser;
  final ConsultationRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActionItem>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const <ActionItem>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              isAdviser
                  ? 'No action items yet. Add what the group should do before the next meeting.'
                  : 'No action items yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          );
        }
        return Column(
          children: [
            for (final item in items)
              _ItemTile(
                item: item,
                isAdviser: isAdviser,
                onToggle: (v) => repo.setDone(item, v),
                onDelete: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete this action item?',
                    message: '"${item.title}" will be removed for the group.',
                    confirmLabel: 'Delete',
                  );
                  if (ok) await repo.deleteItem(item);
                },
              ),
          ],
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.isAdviser,
    required this.onToggle,
    required this.onDelete,
  });

  final ActionItem item;
  final bool isAdviser;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final overdue = item.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Checkbox(
                value: item.done,
                activeColor: AppColors.success,
                onChanged: (v) => onToggle(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: text.titleMedium?.copyWith(
                        decoration:
                        item.done ? TextDecoration.lineThrough : null,
                        color: item.done ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        item.assignee ?? 'Whole group',
                        if (item.due != null)
                          '${overdue ? 'Overdue' : 'Due'} ${DateFormatters.shortDay(item.due!)}',
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(
                          color: overdue ? AppColors.error : AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (isAdviser)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}