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
  UserRole? _selected;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('How will you use ThesisTrack?', style: text.headlineLarge),
              const SizedBox(height: 8),
              Text('This can\'t be changed later, so choose carefully.',
                  style: text.bodySmall),
              const SizedBox(height: 28),
              _RoleCard(
                icon: Icons.person_pin_rounded,
                title: 'I\'m an adviser',
                subtitle: 'Publish slots, log consultations, assign action items.',
                selected: _selected == UserRole.adviser,
                onTap: () => setState(() => _selected = UserRole.adviser),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.groups_rounded,
                title: 'I\'m a student',
                subtitle: 'Book consultations and track my group\'s milestones.',
                selected: _selected == UserRole.student,
                onTap: () => setState(() => _selected = UserRole.student),
              ),
              const Spacer(),
              if (auth.errorMessage != null) ...[
                Text(auth.errorMessage!,
                    style: text.bodyMedium?.copyWith(color: AppColors.error)),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Continue',
                loading: auth.busy,
                onPressed: _selected == null
                    ? null
                    : () => context.read<AuthProvider>().chooseRole(_selected!),
              ),
            ],
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