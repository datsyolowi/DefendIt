import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF092F30), Color(0xFF154C48), Color(0xFF092F30)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -140,
              child: IgnorePointer(
                child: Container(
                  width: 460,
                  height: 460,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x554DAA8D), Color(0x004DAA8D)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -160,
              left: -180,
              child: IgnorePointer(
                child: Container(
                  width: 480,
                  height: 480,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x33E9B65E), Color(0x00E9B65E)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: constraints.maxWidth.clamp(0.0, 420.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.20,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    size: 24,
                                    color: AppColors.amber,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'DefendIt',
                                  style: text.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),
                            Text(
                              'BIG IDEAS. STRONGER DEFENSES.',
                              style: text.bodySmall?.copyWith(
                                fontSize: 10,
                                color: const Color(0xFFECCB91),
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Defend with\nconfidence.',
                              style: text.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 46,
                                height: 1.06,
                                letterSpacing: -2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Your thesis. A clear path forward.',
                              style: text.bodyMedium?.copyWith(
                                color: const Color(0xFFB7CDC5),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Less chaos. More clarity.',
                                          style: text.titleMedium?.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 20,
                                        color: AppColors.amber,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const _FeatureRow(
                                    icon: Icons.event_available_rounded,
                                    label: 'Meet with purpose',
                                    detail: 'Consultations, in sync.',
                                    accent: Color(0xFF9BDAC6),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  const _FeatureRow(
                                    icon: Icons.flag_rounded,
                                    label: 'Make every step count',
                                    detail: 'Milestones, made clear.',
                                    accent: Color(0xFFECCB91),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            if (auth.errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFECE9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  auth.errorMessage!,
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.indigoDark,
                                  disabledBackgroundColor: const Color(
                                    0xFFDCE6E0,
                                  ),
                                  minimumSize: const Size.fromHeight(60),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: auth.busy
                                    ? null
                                    : () => context
                                          .read<AuthProvider>()
                                          .signInWithGoogle(),
                                child: auth.busy
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: AppColors.indigoDark,
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          const Text(
                                            'G',
                                            style: TextStyle(
                                              fontFamily: 'Arial',
                                              fontSize: 24,
                                              height: 1,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4285F4),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              'Continue with Google',
                                              textAlign: TextAlign.center,
                                              style: text.titleMedium?.copyWith(
                                                fontSize: 15,
                                                color: AppColors.indigoDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB7CDC5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
