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

/// An exercise within a planned workout
class PlannedExercise {
  final String exerciseName;
  final ExerciseMode mode;
  final int targetSets;              // For reps, variableSets, static
  final int? targetReps;             // For reps mode
  final List<int>? targetRepsPerSet; // For variableSets mode
  final int? pyramidTop;             // For pyramid mode
  final int? targetSeconds;          // For static mode
  final double targetWeight;
  final int? restBetweenSets;        // Rest in seconds (for reps, pyramid, static)
  final List<int>? restBetweenSetsPerSet; // Rest per set in seconds (for variableSets)
  final int? restAfterExercise;      // Rest after this exercise before next one (in seconds)

  PlannedExercise({
    required this.exerciseName,
    required this.mode,
    this.targetSets = 4,
    this.targetReps,
    this.targetRepsPerSet,
    this.pyramidTop,
    this.targetSeconds,
    this.targetWeight = 0,
    this.restBetweenSets,
    this.restBetweenSetsPerSet,
    this.restAfterExercise,
  });

  /// Calculate total reps for pyramid mode (top² formula)
  int get pyramidTotalReps {
    if (pyramidTop == null || pyramidTop! <= 0) return 0;
    return pyramidTop! * pyramidTop!;
  }

  /// Get display string for this exercise
  String get displayString {
    final weightSuffix = targetWeight != 0 ? ' @ ${targetWeight}kg' : '';

    switch (mode) {
      case ExerciseMode.reps:
        return '$targetSets × ${targetReps ?? 10} reps$weightSuffix';
      case ExerciseMode.variableSets:
        if (targetRepsPerSet == null || targetRepsPerSet!.isEmpty) {
          return '$targetSets sets$weightSuffix';
        }
        final allSame = targetRepsPerSet!.every((r) => r == targetRepsPerSet!.first);
        if (allSame) {
          return '$targetSets × ${targetRepsPerSet!.first} reps$weightSuffix';
        }
        return '$targetSets sets (${targetRepsPerSet!.join(', ')})$weightSuffix';
      case ExerciseMode.pyramid:
        return 'Pyramid to ${pyramidTop ?? 10}$weightSuffix';
      case ExerciseMode.static:
        return '$targetSets × ${targetSeconds ?? 30}s$weightSuffix';
    }
  }

  /// Get mode label
  String get modeLabel {
    switch (mode) {
      case ExerciseMode.reps:
        return 'Reps';
      case ExerciseMode.variableSets:
        return 'Variable';
      case ExerciseMode.pyramid:
        return 'Pyramid';
      case ExerciseMode.static:
        return 'Static';
    }
  }

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'mode': mode.name,
    'targetSets': targetSets,
    'targetReps': targetReps,
    'targetRepsPerSet': targetRepsPerSet,
    'pyramidTop': pyramidTop,
    'targetSeconds': targetSeconds,
    'targetWeight': targetWeight,
    'restBetweenSets': restBetweenSets,
    'restBetweenSetsPerSet': restBetweenSetsPerSet,
    'restAfterExercise': restAfterExercise,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseName: json['exerciseName'] as String,
      mode: ExerciseMode.values.firstWhere(
        (e) => e.name == json['mode'],
      ),
      targetSets: json['targetSets'] as int? ?? 4,
      targetReps: json['targetReps'] as int?,
      targetRepsPerSet: (json['targetRepsPerSet'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      pyramidTop: json['pyramidTop'] as int?,
      targetSeconds: json['targetSeconds'] as int?,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
      restBetweenSets: json['restBetweenSets'] as int?,
      restBetweenSetsPerSet: (json['restBetweenSetsPerSet'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      restAfterExercise: json['restAfterExercise'] as int?,
    );
  }

  /// Create from an Exercise template
  factory PlannedExercise.fromExercise(Exercise exercise) {
    return PlannedExercise(
      exerciseName: exercise.name,
      mode: exercise.mode,
      targetSets: exercise.defaultSets,
      targetReps: exercise.mode == ExerciseMode.reps ? exercise.defaultReps : null,
      targetRepsPerSet: exercise.mode == ExerciseMode.variableSets
          ? List.filled(exercise.defaultSets, exercise.defaultReps)
          : null,
      pyramidTop: exercise.mode == ExerciseMode.pyramid ? exercise.defaultPyramidTop : null,
      targetSeconds: exercise.mode == ExerciseMode.static ? exercise.defaultSeconds : null,
      targetWeight: exercise.defaultWeight,
      restBetweenSets: exercise.mode != ExerciseMode.variableSets ? exercise.defaultRestBetweenSets : null,
      restBetweenSetsPerSet: exercise.mode == ExerciseMode.variableSets
          ? (exercise.defaultRestBetweenSetsPerSet ?? (exercise.defaultRestBetweenSets != null
              ? List.filled(exercise.defaultSets, exercise.defaultRestBetweenSets!)
              : null))
          : null,
    );
  }

  PlannedExercise copyWith({
    String? exerciseName,
    ExerciseMode? mode,
    int? targetSets,
    int? targetReps,
    List<int>? targetRepsPerSet,
    int? pyramidTop,
    int? targetSeconds,
    double? targetWeight,
    int? restBetweenSets,
    List<int>? restBetweenSetsPerSet,
    int? restAfterExercise,
  }) {
    return PlannedExercise(
      exerciseName: exerciseName ?? this.exerciseName,
      mode: mode ?? this.mode,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetRepsPerSet: targetRepsPerSet ?? this.targetRepsPerSet,
      pyramidTop: pyramidTop ?? this.pyramidTop,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      targetWeight: targetWeight ?? this.targetWeight,
      restBetweenSets: restBetweenSets ?? this.restBetweenSets,
      restBetweenSetsPerSet: restBetweenSetsPerSet ?? this.restBetweenSetsPerSet,
      restAfterExercise: restAfterExercise ?? this.restAfterExercise,
    );
  }

  /// Get formatted rest time string for display
  String get restDisplayString {
    if (mode == ExerciseMode.variableSets && restBetweenSetsPerSet != null && restBetweenSetsPerSet!.isNotEmpty) {
      // Check if all rest values are the same
      final allSame = restBetweenSetsPerSet!.every((r) => r == restBetweenSetsPerSet!.first);
      if (allSame && restBetweenSetsPerSet!.first > 0) {
        return _formatSeconds(restBetweenSetsPerSet!.first);
      }
      final formattedRests = restBetweenSetsPerSet!.map(_formatSeconds).join(', ');
      return formattedRests;
    }
    if (restBetweenSets != null && restBetweenSets! > 0) {
      return _formatSeconds(restBetweenSets!);
    }
    return '';
  }

  static String _formatSeconds(int totalSeconds) {
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
}
