import 'package:flutter/material.dart';
import 'exercise.dart';

/// How the workout repeats
enum RecurrenceType {
  oneOff,  // Single occurrence, no repeat
  weekly,  // Repeats every week on same day
  offset,  // Repeats every N days
}

/// Available icons for workouts
class WorkoutIcons {
  static const List<IconData> available = [
    // Strength / weights
    Icons.fitness_center,        // Dumbbell - good for arms/upper body
    Icons.sports_kabaddi,        // Grappling figure - full body
    Icons.sports_gymnastics,     // Gymnast - bodyweight/calisthenics
    Icons.sports_martial_arts,   // Martial arts kick - legs/cardio

    // Cardio
    Icons.directions_run,        // Running
    Icons.directions_bike,       // Cycling
    Icons.rowing,                // Rowing - back/arms
    Icons.pool,                  // Swimming

    // Body/flexibility
    Icons.self_improvement,      // Meditation/yoga pose
    Icons.accessibility_new,     // Standing figure - full body
    Icons.airline_seat_legroom_extra, // Legs stretched
    Icons.sports_handball,       // Throwing - shoulders/arms

    // General workout
    Icons.flash_on,              // Power/intensity
    Icons.local_fire_department, // Burn/cardio
    Icons.timer,                 // Timed workout
    Icons.speed,                 // HIIT/speed
    Icons.trending_up,           // Progress/gains
    Icons.bolt,                  // Energy/power

    // Other sports
    Icons.sports,                // General sports
    Icons.sports_score,          // Goal/target
    Icons.emoji_events,          // Trophy/achievement
    Icons.military_tech,         // Medal/achievement
    Icons.star,                  // Favorite
    Icons.favorite,              // Heart/cardio
  ];

  /// Default icon if none selected
  static const IconData defaultIcon = Icons.fitness_center;

  /// Get IconData from codePoint
  static IconData fromCodePoint(int? codePoint) {
    if (codePoint == null) return defaultIcon;
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }
}

/// A planned workout consisting of multiple exercises
class Workout {
  final String id;
  final String name;
  final int iconCodePoint; // Store icon as codePoint for serialization
  final List<PlannedExercise> exercises;
  final DateTime startDate;
  final RecurrenceType recurrenceType;
  final int? offsetDays; // Only used when recurrenceType is offset

  Workout({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.exercises,
    required this.startDate,
    required this.recurrenceType,
    this.offsetDays,
  });

  /// Get the actual IconData
  IconData get icon => WorkoutIcons.fromCodePoint(iconCodePoint);

  factory Workout.create({
    required String name,
    required DateTime startDate,
    required RecurrenceType recurrenceType,
    IconData? icon,
    int? offsetDays,
    List<PlannedExercise>? exercises,
  }) {
    return Workout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      iconCodePoint: (icon ?? WorkoutIcons.defaultIcon).codePoint,
      exercises: exercises ?? [],
      startDate: startDate,
      recurrenceType: recurrenceType,
      offsetDays: offsetDays,
    );
  }

  /// Check if this workout occurs on a given date
  bool occursOn(DateTime date) {
    // Normalize to just the date (no time)
    final targetDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    // Can't occur before start date
    if (targetDate.isBefore(start)) return false;

    switch (recurrenceType) {
      case RecurrenceType.oneOff:
        return targetDate.isAtSameMomentAs(start);

      case RecurrenceType.weekly:
        // Same day of week
        return targetDate.weekday == start.weekday;

      case RecurrenceType.offset:
        if (offsetDays == null || offsetDays! <= 0) return false;
        final daysDiff = targetDate.difference(start).inDays;
        return daysDiff % offsetDays! == 0;
    }
  }

  /// Get all occurrences of this workout in a date range
  List<DateTime> getOccurrencesInRange(DateTime from, DateTime to) {
    final occurrences = <DateTime>[];
    var current = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    while (!current.isAfter(end)) {
      if (occursOn(current)) {
        occurrences.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return occurrences;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconCodePoint': iconCodePoint,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'startDate': startDate.toIso8601String(),
    'recurrenceType': recurrenceType.name,
    'offsetDays': offsetDays,
  };

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int? ?? WorkoutIcons.defaultIcon.codePoint,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      startDate: DateTime.parse(json['startDate'] as String),
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == json['recurrenceType'],
      ),
      offsetDays: json['offsetDays'] as int?,
    );
  }

  Workout copyWith({
    String? name,
    IconData? icon,
    List<PlannedExercise>? exercises,
    DateTime? startDate,
    RecurrenceType? recurrenceType,
    int? offsetDays,
  }) {
    return Workout(
      id: id,
      name: name ?? this.name,
      iconCodePoint: icon?.codePoint ?? iconCodePoint,
      exercises: exercises ?? this.exercises,
      startDate: startDate ?? this.startDate,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      offsetDays: offsetDays ?? this.offsetDays,
    );
  }
}

/// An exercise within a planned workout (template, not a log entry)
class PlannedExercise {
  final String exerciseName;
  final ExerciseType exerciseType;
  final int targetSets;
  final int targetRepsOrDuration;
  final double targetWeight;

  PlannedExercise({
    required this.exerciseName,
    required this.exerciseType,
    required this.targetSets,
    required this.targetRepsOrDuration,
    this.targetWeight = 0,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'exerciseType': exerciseType.name,
    'targetSets': targetSets,
    'targetRepsOrDuration': targetRepsOrDuration,
    'targetWeight': targetWeight,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseName: json['exerciseName'] as String,
      exerciseType: ExerciseType.values.firstWhere(
        (e) => e.name == json['exerciseType'],
      ),
      targetSets: json['targetSets'] as int,
      targetRepsOrDuration: json['targetRepsOrDuration'] as int,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
    );
  }

  PlannedExercise copyWith({
    String? exerciseName,
    ExerciseType? exerciseType,
    int? targetSets,
    int? targetRepsOrDuration,
    double? targetWeight,
  }) {
    return PlannedExercise(
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseType: exerciseType ?? this.exerciseType,
      targetSets: targetSets ?? this.targetSets,
      targetRepsOrDuration: targetRepsOrDuration ?? this.targetRepsOrDuration,
      targetWeight: targetWeight ?? this.targetWeight,
    );
  }

  String get repsOrDurationLabel =>
      exerciseType == ExerciseType.dynamic ? 'reps' : 'seconds';
}
