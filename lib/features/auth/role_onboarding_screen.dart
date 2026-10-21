import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/utils/student_number.dart';
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
  final _studentNo = TextEditingController();
  final _teammateCode = TextEditingController();
  UserRole? _selected;

  @override
  void dispose() {
    _code.dispose();
    _studentNo.dispose();
    _teammateCode.dispose();
    super.dispose();
  }

  void _continue() {
    final role = _selected;
    if (role == null) return;
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().chooseRole(
      role,
      adviserCode: role == UserRole.adviser ? _code.text : null,
      studentNumber: role == UserRole.student ? _studentNo.text : null,
      teammateCode: role == UserRole.student ? _teammateCode.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE2EEE8), Color(0xFFF9FAF6), Color(0xFFEDE9DC)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(0.0, 460.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.indigoDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.indigoDark.withValues(
                                        alpha: 0.16,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: AppColors.amber,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'DefendIt',
                                style: text.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: AppColors.indigo.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.indigoDark.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                                BoxShadow(
                                  color: AppColors.indigoDark.withValues(
                                    alpha: 0.03,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Defend with confidence.',
                                    style: text.headlineLarge?.copyWith(
                                      fontSize: 34,
                                      height: 1.1,
                                      letterSpacing: -1.3,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Choose your role. It's a one-time choice.",
                                    style: text.bodySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  _RoleCard(
                                    icon: Icons.person_pin_rounded,
                                    title: 'Adviser',
                                    subtitle: 'Guide groups. Shape progress.',
                                    selected: _selected == UserRole.adviser,
                                    onTap: () => setState(
                                      () => _selected = UserRole.adviser,
                                    ),
                                  ),
                                  if (_selected == UserRole.adviser) ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _code,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      autocorrect: false,
                                      inputFormatters: [
                                        _AdviserCodeFormatter(),
                                      ],
                                      maxLength: 13,
                                      decoration: const InputDecoration(
                                        labelText: 'Adviser access code',
                                        hintText: 'CPE-2026-XXXX',
                                        counterText: '',
                                      ),
                                      validator: (v) =>
                                          (v ?? '').trim().length < 8
                                          ? 'Enter your adviser access code'
                                          : null,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _RoleCard(
                                    icon: Icons.groups_rounded,
                                    title: 'Student',
                                    subtitle:
                                        'Book meetings. Track milestones.',
                                    selected: _selected == UserRole.student,
                                    onTap: () => setState(
                                      () => _selected = UserRole.student,
                                    ),
                                  ),
                                  if (_selected == UserRole.student) ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _studentNo,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        StudentNumberFormatter(),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Student number',
                                        hintText: '202X-XXXXXX',
                                        helperText: 'Example: 202X-XXXXXX',
                                      ),
                                      validator: StudentNumber.validator,
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _teammateCode,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      autocorrect: false,
                                      maxLength: 6,
                                      decoration: const InputDecoration(
                                        labelText: 'Teammate code (optional)',
                                        helperText:
                                            'Joining your group? Enter the code from your group leader. Group leaders leave this empty and create the group next.',
                                        helperMaxLines: 3,
                                      ),
                                      validator: (v) {
                                        final t = (v ?? '').trim();
                                        return t.isEmpty || t.length == 6
                                            ? null
                                            : 'The code has 6 characters';
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  if (auth.errorMessage != null) ...[
                                    Text(
                                      auth.errorMessage!,
                                      style: text.bodyMedium?.copyWith(
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      elevatedButtonTheme:
                                          ElevatedButtonThemeData(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.indigoDark,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  AppColors.border,
                                              disabledForegroundColor:
                                                  AppColors.muted,
                                              minimumSize:
                                                  const Size.fromHeight(56),
                                              elevation: 2,
                                              shadowColor: AppColors.indigo
                                                  .withValues(alpha: 0.25),
                                              textStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                    ),
                                    child: PrimaryButton(
                                      label: 'Continue',
                                      icon: Icons.arrow_forward_rounded,
                                      loading: auth.busy,
                                      onPressed: _selected == null
                                          ? null
                                          : _continue,
                                    ),
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
        ),
      ),
    );
  }
}

class _AdviserCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final code = raw.substring(0, raw.length.clamp(0, 11));
    final buffer = StringBuffer();
    for (var i = 0; i < code.length; i++) {
      if (i == 3 || i == 7) buffer.write('-');
      buffer.write(code[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigoTint : const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : AppColors.indigoTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: AppColors.indigo),
            ),
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
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.indigo : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
