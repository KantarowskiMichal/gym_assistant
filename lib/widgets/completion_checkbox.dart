import 'package:flutter/material.dart';

/// A circular checkbox widget for marking workouts as complete/incomplete.
///
/// Displays a green checkmark when completed, or an empty circle when incomplete.
/// Used in Today screen and Calendar screen for workout completion tracking.
class CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback onTap;
  final double size;

  const CompletionCheckbox({
    super.key,
    required this.isCompleted,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: _buildDecoration(context),
        child: isCompleted ? _buildCheckIcon() : null,
      ),
    );
  }

  BoxDecoration _buildDecoration(BuildContext context) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: _getBackgroundColor(context),
      border: _getBorder(context),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    return isCompleted
        ? Colors.green
        : Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Border? _getBorder(BuildContext context) {
    if (isCompleted) return null;
    return Border.all(
      color: Theme.of(context).colorScheme.outline,
      width: 2,
    );
  }

  Widget _buildCheckIcon() {
    return Icon(
      Icons.check,
      color: Colors.white,
      size: size * 0.625, // Scale icon proportionally (20/32 = 0.625)
    );
  }
}
