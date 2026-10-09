import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/group.dart';
import '../../data/repositories/group_repository.dart';
import '../auth/auth_provider.dart';
import 'group_form_sheets.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final Stream<List<Group>> _stream;
  late final AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().profile!;
    _stream = context.read<GroupRepository>().watchMyGroups(_user);
  }

  bool get _isStudent => _user.role == UserRole.student;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: _isStudent ? 'Join with code' : 'Advise a group',
            icon: const Icon(Icons.vpn_key_rounded),
            onPressed: () => showJoinGroupSheet(context, _user),
          ),
        ],
      ),
      floatingActionButton: _isStudent
          ? FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        onPressed: () => showCreateGroupSheet(context, _user),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New group'),
      )
          : null,
      body: StreamBuilder<List<Group>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorView(
                message: 'Could not load your groups. Check your connection.');
          }
          if (!snap.hasData) return const LoadingView();

          final groups = snap.data!;
          if (groups.isEmpty) {
            return EmptyState(
              icon: Icons.groups_rounded,
              title: 'No groups yet',
              message: _isStudent
                  ? 'Create a group for your thesis team, or join one with a code.'
                  : 'Ask a student group for its code, then tap the key icon to become its adviser.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GroupCard(group: groups[i]),
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(group.thesisTitle, style: text.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_pin_rounded,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.adviserName == null
                        ? 'No adviser yet'
                        : 'Adviser: ${group.adviserName}',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.groups_rounded,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.memberNames.values.join(', '),
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
                    Text('Code: ${group.code}',
                        style: text.titleMedium
                            ?.copyWith(color: AppColors.indigo, letterSpacing: 1.5)),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.indigo),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}