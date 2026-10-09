import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: AppColors.indigoTint, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: AppColors.indigo),
            ),
            const SizedBox(height: 20),
            Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: text.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}