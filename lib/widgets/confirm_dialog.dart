import 'package:flutter/material.dart';

/// Shows a confirmation dialog and returns true if confirmed, false if cancelled.
///
/// Used throughout the app for confirming destructive actions like deletions.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: isDestructive
                ? const TextStyle(color: Colors.red)
                : null,
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
