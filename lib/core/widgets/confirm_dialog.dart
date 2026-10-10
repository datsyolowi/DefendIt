import 'package:flutter/material.dart';

Future<bool> confirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String confirmLabel = 'Confirm',
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}