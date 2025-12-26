import 'package:flutter/material.dart';
import 'converters.dart';

// ============ TIME FORMATTING ============

/// Format seconds to human-readable string (e.g., "1m 30s", "45s")
String formatSeconds(int totalSeconds) {
  if (totalSeconds <= 0) return '0s';
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

// ============ EXERCISE HELPERS ============

/// Extension methods for ExerciseSet
extension ExerciseSetHelpers on ExerciseSet {
  /// Get formatted rest time string
  String? get restDisplay {
    if (rest == null) return null;
    return formatSeconds(rest!);
  }

  /// Get value display based on exercise type
  String valueDisplay(ExerciseType type) {
    switch (type) {
      case ExerciseType.dynamic:
        return '$value reps';
      case ExerciseType.static:
        return formatSeconds(value);
    }
  }

  /// Get weight display string
  String? get weightDisplay {
    if (weight == 0) return null;
    return '${weight}kg';
  }
}

/// Get mode-appropriate display label
String getModeLabelFor(ExerciseMode mode) {
  switch (mode) {
    case ExerciseMode.reps:
      return 'Reps';
    case ExerciseMode.variableSets:
      return 'Variable';
    case ExerciseMode.pyramid:
      return 'Pyramid';
  }
}

/// Get type-appropriate display label
String getTypeLabelFor(ExerciseType type) {
  switch (type) {
    case ExerciseType.static:
      return 'Static';
    case ExerciseType.dynamic:
      return 'Dynamic';
  }
}

/// Get a summary string for sets
String getSetsSummary(List<ExerciseSet> sets, ExerciseType type) {
  if (sets.isEmpty) return 'No sets configured';

  final setCount = sets.length;
  final firstSet = sets.first;

  switch (type) {
    case ExerciseType.dynamic:
      final allSameValue = sets.every((s) => s.value == firstSet.value);
      if (allSameValue) {
        return '$setCount × ${firstSet.value} reps';
      }
      return '$setCount sets (${sets.map((s) => s.value).join(', ')})';
    case ExerciseType.static:
      final allSameValue = sets.every((s) => s.value == firstSet.value);
      if (allSameValue) {
        return '$setCount × ${firstSet.value}s';
      }
      return '$setCount sets (${sets.map((s) => '${s.value}s').join(', ')})';
  }
}

// ============ WORKOUT ICONS ============

/// Available icons for workouts
class WorkoutIcons {
  static const List<IconData> available = [
    // Strength / weights
    Icons.fitness_center, // Dumbbell - good for arms/upper body
    Icons.sports_kabaddi, // Grappling figure - full body
    Icons.sports_gymnastics, // Gymnast - bodyweight/calisthenics
    Icons.sports_martial_arts, // Martial arts kick - legs/cardio

    // Cardio
    Icons.directions_run, // Running
    Icons.directions_bike, // Cycling
    Icons.rowing, // Rowing - back/arms
    Icons.pool, // Swimming

    // Body/flexibility
    Icons.self_improvement, // Meditation/yoga pose
    Icons.accessibility_new, // Standing figure - full body
    Icons.airline_seat_legroom_extra, // Legs stretched
    Icons.sports_handball, // Throwing - shoulders/arms

    // General workout
    Icons.flash_on, // Power/intensity
    Icons.local_fire_department, // Burn/cardio
    Icons.timer, // Timed workout
    Icons.speed, // HIIT/speed
    Icons.trending_up, // Progress/gains
    Icons.bolt, // Energy/power

    // Other sports
    Icons.sports, // General sports
    Icons.sports_score, // Goal/target
    Icons.emoji_events, // Trophy/achievement
    Icons.military_tech, // Medal/achievement
    Icons.star, // Favorite
    Icons.favorite, // Heart/cardio
  ];

  /// Default icon if none selected
  static const IconData defaultIcon = Icons.fitness_center;

  /// Get IconData from codePoint
  static IconData fromCodePoint(int? codePoint) {
    if (codePoint == null) return defaultIcon;
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }
}

// ============ SCHEDULE HELPERS ============

/// Check if a schedule occurs on a given date
bool scheduleOccursOn({
  required DateTime startDate,
  required RecurrenceType recurrenceType,
  required int? offsetDays,
  required DateTime targetDate,
}) {
  // Normalize to just the date (no time)
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);

  // Can't occur before start date
  if (target.isBefore(start)) return false;

  switch (recurrenceType) {
    case RecurrenceType.oneOff:
      return target.isAtSameMomentAs(start);

    case RecurrenceType.weekly:
      // Same day of week
      return target.weekday == start.weekday;

    case RecurrenceType.offset:
      if (offsetDays == null || offsetDays <= 0) return false;
      final daysDiff = target.difference(start).inDays;
      return daysDiff % offsetDays == 0;
  }
}

/// Get all occurrences of a schedule in a date range
List<DateTime> getScheduleOccurrencesInRange({
  required DateTime startDate,
  required RecurrenceType recurrenceType,
  required int? offsetDays,
  required DateTime from,
  required DateTime to,
}) {
  final occurrences = <DateTime>[];
  var current = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);

  while (!current.isAfter(end)) {
    if (scheduleOccursOn(
      startDate: startDate,
      recurrenceType: recurrenceType,
      offsetDays: offsetDays,
      targetDate: current,
    )) {
      occurrences.add(current);
    }
    current = current.add(const Duration(days: 1));
  }
  return occurrences;
}
