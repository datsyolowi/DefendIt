import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/limits.dart';
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

// ───────────────────────── Create group ─────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.user});
  final AppUser user;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _section = TextEditingController();
  final _title = TextEditingController();
  late final List<TextEditingController> _members;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Row 0 is the leader (prefilled from the Google account), row 1 a teammate.
    _members = [
      TextEditingController(text: widget.user.name),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _title.dispose();
    for (final c in _members) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMember() {
    if (_members.length >= Limits.maxGroupMembers) return;
    setState(() => _members.add(TextEditingController()));
  }

  void _removeMember(int index) {
    if (index == 0 || _members.length <= Limits.minGroupMembers) return;
    setState(() => _members.removeAt(index).dispose());
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
        section: _section.text,
        thesisTitle: _title.text,
        members: _members.map((c) => c.text).toList(),
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
    final text = Theme.of(context).textTheme;
    return _SheetFrame(
      title: 'Create a group',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              controller: _section,
              decoration: const InputDecoration(
                  labelText: 'Section', hintText: 'BSCPE 4-X'),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [_SectionFormatter()],
              validator: (v) =>
                  Validators.text(v, label: 'Section', min: 2, max: 30),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Thesis topic'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  Validators.text(v, label: 'Thesis topic', min: 5, max: 160),
            ),
            const SizedBox(height: 22),
            Text('Members (${_members.length}/${Limits.maxGroupMembers})',
                style: text.titleMedium),
            const SizedBox(height: 4),
            Text('You are the group leader. List your teammates by full name.',
                style: text.bodySmall),
            const SizedBox(height: 12),
            for (var i = 0; i < _members.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _members[i],
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText:
                          i == 0 ? 'Your name (leader)' : 'Member ${i + 1}',
                        ),
                        validator: (v) =>
                            Validators.text(v, label: 'Name', min: 2, max: 60),
                      ),
                    ),
                    if (i > 0 && _members.length > Limits.minGroupMembers)
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _removeMember(i),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            if (_members.length < Limits.maxGroupMembers)
              TextButton.icon(
                onPressed: _addMember,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add member'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
                label: 'Create group', loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Join group (students) ─────────────────────────

class _SectionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;

    final text = newValue.text;
    var changeStart = 0;
    while (changeStart < oldValue.text.length &&
        changeStart < text.length &&
        oldValue.text[changeStart] == text[changeStart]) {
      changeStart++;
    }
    var oldEnd = oldValue.text.length;
    var newEnd = text.length;
    while (oldEnd > changeStart &&
        newEnd > changeStart &&
        oldValue.text[oldEnd - 1] == text[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }

    // Only a newly inserted first digit triggers formatting. Deletions never
    // restore a removed dash, and the section number does not add another one.
    final digit = RegExp(r'[0-9]').firstMatch(text);
    final insertAt = !text.contains('-') &&
            digit != null &&
            digit.start >= changeStart &&
            digit.start < newEnd
        ? digit.end
        : -1;
    final formatted = insertAt < 0
        ? text.toUpperCase()
        : '${text.substring(0, insertAt).toUpperCase()}-'
            '${text.substring(insertAt).toUpperCase()}';

    int mapOffset(int offset) {
      if (offset < 0) return offset;
      final mapped = text.substring(0, offset).toUpperCase().length;
      return mapped + (insertAt >= 0 && offset >= insertAt ? 1 : 0);
    }

    return TextEditingValue(
      text: formatted,
      selection: newValue.selection.copyWith(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
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
    return _SheetFrame(
      title: 'Join a group',
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
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
                label: 'Join group', loading: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
