import 'package:flutter/material.dart';

/// Shows a dialog asking if the user wants to modify the workout before completing.
///
/// Returns true if user wants to modify, false if they want to complete as-is,
/// and null if they cancel.
Future<bool?> showCompletionOptionsDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Complete Workout'),
      content: const Text('Do you want to modify the workout before completing?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
}
