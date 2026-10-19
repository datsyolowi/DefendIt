import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/app_user.dart';
import 'auth_provider.dart';

class RoleOnboardingScreen extends StatefulWidget {
  const RoleOnboardingScreen({super.key});

  @override
  State<RoleOnboardingScreen> createState() => _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends State<RoleOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  UserRole? _selected;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _continue() {
    final role = _selected;
    if (role == null) return;
    if (role == UserRole.adviser && !_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().chooseRole(
          role,
          adviserCode: role == UserRole.adviser ? _code.text : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('How will you use ThesisTrack?',
                    style: text.headlineLarge),
                const SizedBox(height: 8),
                Text('This can\'t be changed later, so choose carefully.',
                    style: text.bodySmall),
                const SizedBox(height: 28),
                _RoleCard(
                  icon: Icons.person_pin_rounded,
                  title: 'I\'m an adviser',
                  subtitle:
                      'Publish slots, log consultations, assign action items.',
                  selected: _selected == UserRole.adviser,
                  onTap: () => setState(() => _selected = UserRole.adviser),
                ),
                if (_selected == UserRole.adviser) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Adviser access code',
                      hintText: 'CPE-XXXX-XXXX',
                      helperText:
                          'Enter the one-time code you received from the administrator.',
                      helperMaxLines: 2,
                    ),
                    validator: (v) => (v ?? '').trim().length < 8
                        ? 'Enter your adviser access code'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.groups_rounded,
                  title: 'I\'m a student',
                  subtitle:
                      'Book consultations and track my group\'s milestones.',
                  selected: _selected == UserRole.student,
                  onTap: () => setState(() => _selected = UserRole.student),
                ),
                const SizedBox(height: 32),
                if (auth.errorMessage != null) ...[
                  Text(auth.errorMessage!,
                      style:
                          text.bodyMedium?.copyWith(color: AppColors.error)),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Continue',
                  loading: auth.busy,
                  onPressed: _selected == null ? null : _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigoTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: AppColors.indigo),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}