import 'package:flutter/material.dart';

/// A container that displays a workout icon with completion-aware styling.
///
/// Shows the icon with:
/// - Green tint when completed
/// - Primary color tint when not completed
/// Used across multiple screens for consistent workout icon display.
class WorkoutIconContainer extends StatelessWidget {
  final IconData icon;
  final bool isCompleted;
  final double size;

  const WorkoutIconContainer({
    super.key,
    required this.icon,
    this.isCompleted = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: _buildDecoration(context),
      child: Icon(
        icon,
        color: _getIconColor(context),
      ),
    );
  }

  BoxDecoration _buildDecoration(BuildContext context) {
    return BoxDecoration(
      color: _getBackgroundColor(context),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    return isCompleted
        ? Colors.green.withValues(alpha: 0.2)
        : Theme.of(context).colorScheme.primaryContainer;
  }

  Color _getIconColor(BuildContext context) {
    return isCompleted
        ? Colors.green
        : Theme.of(context).colorScheme.primary;
  }
}
