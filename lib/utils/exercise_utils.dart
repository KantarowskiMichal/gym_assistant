import 'package:flutter/material.dart';
import '../models/exercise.dart';

/// Utility functions for exercise-related operations.

/// Returns the color associated with a specific exercise mode.
///
/// Used for mode chips and visual indicators across the app.
Color? getModeColor(ExerciseMode mode) => switch (mode) {
      ExerciseMode.reps => Colors.green[100],
      ExerciseMode.variableSets => Colors.blue[100],
      ExerciseMode.pyramid => Colors.purple[100],
      ExerciseMode.static => Colors.orange[100],
    };

/// Format seconds as "Xm Ys" or "Ys" string for display.
///
/// Examples:
/// - 90 seconds → "1m 30s"
/// - 60 seconds → "1m"
/// - 45 seconds → "45s"
/// - 0 seconds → ""
String formatRestTime(int totalSeconds) {
  if (totalSeconds <= 0) return '';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes > 0 && seconds > 0) {
    return '${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m';
  } else {
    return '${seconds}s';
  }
}
