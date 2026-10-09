import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/group_repository.dart';

Future<void> showCreateGroupSheet(BuildContext context, AppUser user) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CreateGroupSheet(user: user),
  );
}

Future<void> showJoinGroupSheet(BuildContext context, AppUser user) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JoinGroupSheet(user: user),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.user});
  final AppUser user;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _title = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<GroupRepository>().createGroup(
        student: widget.user,
        name: _name.text,
        thesisTitle: _title.text,
      );
      if (mounted) Navigator.pop(context);
    } on GroupFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create the group. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Create a group',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Group name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  Validators.text(v, label: 'Group name', min: 2, max: 40),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration:
              const InputDecoration(labelText: 'Working thesis title'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  Validators.text(v, label: 'Thesis title', min: 5, max: 160),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Create group', loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet({required this.user});
  final AppUser user;

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<GroupRepository>()
          .joinByCode(widget.user, _code.text);
      if (mounted) Navigator.pop(context);
    } on GroupFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not join the group. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdviser = widget.user.role == UserRole.adviser;
    return _SheetFrame(
      title: isAdviser ? 'Advise a group' : 'Join a group',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Group code'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              validator: Validators.joinCode,
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
                label: isAdviser ? 'Become adviser' : 'Join group',
                loading: _busy,
                onPressed: _submit),
          ],
        ),
      ),
    );
  }
}