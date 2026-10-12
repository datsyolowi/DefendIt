import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/group.dart';
import '../../data/models/title_idea.dart';
import '../../data/repositories/title_repository.dart';

/// [onAccept] runs the confirm + accept flow and returns true on success,
/// in which case the panel closes itself.
Future<void> showGroupPreviewSheet(
    BuildContext context, {
      required Group group,
      required Future<bool> Function() onAccept,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _GroupPreview(group: group, onAccept: onAccept),
  );
}

class _GroupPreview extends StatefulWidget {
  const _GroupPreview({required this.group, required this.onAccept});
  final Group group;
  final Future<bool> Function() onAccept;

  @override
  State<_GroupPreview> createState() => _GroupPreviewState();
}

class _GroupPreviewState extends State<_GroupPreview> {
  late final Stream<List<TitleIdea>> _titles;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _titles = context.read<TitleRepository>().watchTitles(widget.group.id);
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final ok = await widget.onAccept();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final text = Theme.of(context).textTheme;
    final section = (g.section == null || g.section!.isEmpty)
        ? 'Not provided'
        : g.section!;

    return StreamBuilder<List<TitleIdea>>(
      stream: _titles,
      builder: (context, snap) {
        final all = snap.data ?? const <TitleIdea>[];
        final shown = all.take(3).toList();
        final extra = all.length - shown.length;
        // Header: the group's first proposed title, else the group name.
        final header = shown.isNotEmpty ? shown.first.title : g.name;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GROUP REQUEST',
                          style: text.bodySmall?.copyWith(
                              letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(header, style: text.headlineMedium),
                      const SizedBox(height: 18),
                      _DetailRow(label: 'Group', value: g.name),
                      _DetailRow(label: 'Section', value: section),
                      _DetailRow(label: 'Thesis topic', value: g.thesisTitle),
                      _DetailRow(
                          label: 'Members (${g.roster.length})',
                          value: g.rosterLabel),
                      const SizedBox(height: 8),
                      Text('Proposed titles', style: text.titleMedium),
                      const SizedBox(height: 10),
                      if (snap.hasError)
                        Text('Could not load title ideas.',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.error))
                      else if (shown.isEmpty)
                        Text(
                            snap.hasData
                                ? 'No title ideas yet. This group has not proposed any titles.'
                                : 'Loading…',
                            style: text.bodySmall)
                      else ...[
                          for (var i = 0; i < shown.length; i++)
                            _TitleCard(index: i + 1, idea: shown[i]),
                          if (extra > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                  '+ $extra more title idea${extra == 1 ? '' : 's'} not shown',
                                  style: text.bodySmall),
                            ),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Accept group',
                loading: _busy,
                onPressed: _accept,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.index, required this.idea});
  final int index;
  final TitleIdea idea;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.indigoTint, shape: BoxShape.circle),
            child: Text('$index',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(idea.title, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(idea.description,
                    style: text.bodySmall,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                if (idea.purpose.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Purpose: ${idea.purpose}',
                      style: text.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}