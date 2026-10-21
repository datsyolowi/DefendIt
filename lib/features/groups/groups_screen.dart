import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../titles/group_preview_sheet.dart';
import '../titles/title_ideas_screen.dart';
import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';
import '../auth/auth_provider.dart';
import 'group_form_sheets.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().profile!;
    return user.role == UserRole.adviser
        ? _AdviserGroups(user: user)
        : _StudentGroups(user: user);
  }
}

// ───────────────────────── Student ─────────────────────────

class _StudentGroups extends StatefulWidget {
  const _StudentGroups({required this.user});
  final AppUser user;

  @override
  State<_StudentGroups> createState() => _StudentGroupsState();
}

class _StudentGroupsState extends State<_StudentGroups> {
  late final Stream<List<Group>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<GroupRepository>().watchMyGroups(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Group>>(
      stream: _stream,
      builder: (context, snap) {
        final groups = snap.data;
        final canAdd = groups != null && groups.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My group'),
            actions: [
              if (canAdd)
                IconButton(
                  tooltip: 'Join with code',
                  icon: const Icon(Icons.vpn_key_rounded),
                  onPressed: () => showJoinGroupSheet(context, widget.user),
                ),
            ],
          ),
          floatingActionButton: canAdd
              ? FloatingActionButton.extended(
            backgroundColor: AppColors.amber,
            foregroundColor: AppColors.ink,
            onPressed: () => showCreateGroupSheet(context, widget.user),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create group'),
          )
              : null,
          body: Builder(
            builder: (_) {
              if (snap.hasError) {
                return const ErrorView(
                    message: 'Could not load your group. Check your connection.');
              }
              if (groups == null) return const LoadingView();
              return _GroupList(
                groups: groups,
                showCode: true,
                emptyTitle: 'No group yet',
                emptyMessage:
                'Create your thesis group as its leader, or join your leader\'s group with their code. Each student can only be in one group.',
              );
            },
          ),
        );
      },
    );
  }
}

// ───────────────────────── Adviser ─────────────────────────

class _AdviserGroups extends StatefulWidget {
  const _AdviserGroups({required this.user});
  final AppUser user;

  @override
  State<_AdviserGroups> createState() => _AdviserGroupsState();
}

class _AdviserGroupsState extends State<_AdviserGroups> {
  late final Stream<List<Group>> _mine;
  late final Stream<List<Group>> _open;

  @override
  void initState() {
    super.initState();
    final repo = context.read<GroupRepository>();
    _mine = repo.watchMyGroups(widget.user);
    _open = repo.watchOpenGroups();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Group>>(
      stream: _mine,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Groups')),
            body: const ErrorView(
                message: 'Could not load your groups. Check your connection.'),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Groups')),
            body: const LoadingView(),
          );
        }

        final mine = snap.data!;
        final full = mine.length >= Limits.maxAdviserGroups;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Groups (${mine.length}/${Limits.maxAdviserGroups})'),
              bottom: const TabBar(
                tabs: [Tab(text: 'My groups'), Tab(text: 'Requests')],
              ),
            ),
            body: TabBarView(
              children: [
                _GroupList(
                  groups: mine,
                  showCode: false,
                  emptyTitle: 'No groups yet',
                  emptyMessage:
                  'Open the Requests tab to see student groups looking for an adviser.',
                ),
                _RequestsTab(
                  user: widget.user,
                  stream: _open,
                  full: full,
                  acceptedCount: mine.length,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.user,
    required this.stream,
    required this.full,
    required this.acceptedCount,
  });

  final AppUser user;
  final Stream<List<Group>> stream;
  final bool full;
  final int acceptedCount;

  @override
  Widget build(BuildContext context) {
    if (full) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'You\'re at capacity',
        message:
        'You advise the maximum of ${Limits.maxAdviserGroups} groups, so new requests are hidden.',
      );
    }

    return StreamBuilder<List<Group>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const ErrorView(
              message: 'Could not load requests. Check your connection.');
        }
        if (!snap.hasData) return const LoadingView();

        final groups = snap.data!;
        if (groups.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No open requests',
            message: 'When a student group is created, it will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _RequestCard(
            group: groups[i],
            onView: () => showGroupPreviewSheet(
              context,
              group: groups[i],
              onAccept: () => _accept(context, groups[i]),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _accept(BuildContext context, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this group?'),
        content: Text(
            'You will advise "${group.name}". This would be group ${acceptedCount + 1} of ${Limits.maxAdviserGroups}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<GroupRepository>().acceptGroup(user, group.id);
      messenger.showSnackBar(
          SnackBar(content: Text('You are now advising ${group.name}')));
      return true;
    } on GroupFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not accept the group.')));
      return false;
    }
  }
}

// ───────────────────────── Shared pieces ─────────────────────────

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.showCode,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<Group> groups;
  final bool showCode;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.groups_rounded,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _GroupCard(group: groups[i], showCode: showCode),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.showCode});
  final Group group;
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasAdviser = group.adviserName != null;
    final hasSection = group.section != null && group.section!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TitleIdeasScreen(group: group),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(group.name, style: text.titleMedium)),
                  _StatusChip(awaiting: !hasAdviser),
                ],
              ),
              const SizedBox(height: 4),
              Text(group.thesisTitle, style: text.bodyMedium),
              const SizedBox(height: 12),
              if (hasSection) ...[
                _InfoRow(icon: Icons.class_rounded, text: group.section!),
                const SizedBox(height: 6),
              ],
              _InfoRow(
                icon: Icons.person_pin_rounded,
                text: hasAdviser
                    ? 'Adviser: ${group.adviserName}'
                    : 'Awaiting adviser',
              ),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.groups_rounded, text: group.rosterLabel),
              if (showCode) ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: group.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group code copied')),
                    );
                  },
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.indigoTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text('Teammate code: ${group.code}',
                            style: text.titleMedium?.copyWith(
                                color: AppColors.indigo, letterSpacing: 0.4))),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.indigo),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: AppColors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Title ideas',
                        style: text.bodyMedium?.copyWith(
                            color: AppColors.indigo,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.group, required this.onView});
  final Group group;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = group.roster.length;
    final hasSection = group.section != null && group.section!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: text.titleMedium),
            if (hasSection) ...[
              const SizedBox(height: 2),
              Text(group.section!, style: text.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(group.thesisTitle, style: text.bodyMedium),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.groups_rounded,
              text: '$count member${count == 1 ? '' : 's'}: ${group.rosterLabel}',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                onPressed: onView,
                child: const Text('View details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.awaiting});
  final bool awaiting;

  @override
  Widget build(BuildContext context) {
    final color = awaiting ? AppColors.amber : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        awaiting ? 'Awaiting' : 'Active',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}