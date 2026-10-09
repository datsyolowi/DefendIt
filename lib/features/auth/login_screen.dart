import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
              const Spacer(),
              const Icon(Icons.school_rounded, size: 48, color: AppColors.amber),
              const SizedBox(height: 16),
              Text('ThesisTrack', style: text.headlineLarge),
              const SizedBox(height: 8),
              Text('Every consultation, every action item, every milestone.',
                  style: text.bodyMedium),
              const Spacer(),
              if (auth.errorMessage != null) ...[
                Text(auth.errorMessage!,
                    style: text.bodyMedium?.copyWith(color: AppColors.error)),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: 'Continue with Google',
                icon: Icons.login_rounded,
                loading: auth.busy,
                onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}