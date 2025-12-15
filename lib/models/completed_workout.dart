import 'workout.dart';

/// Represents a completed workout instance - a snapshot of the workout
/// as it was performed on a specific date.
class CompletedWorkout {
  final String id;
  final String scheduledWorkoutId;
  final String workoutName;
  final int iconCodePoint;
  final List<PlannedExercise> exercises;
  final DateTime scheduledDate;
  final DateTime completedAt;

  CompletedWorkout({
    required this.id,
    required this.scheduledWorkoutId,
    required this.workoutName,
    required this.iconCodePoint,
    required this.exercises,
    required this.scheduledDate,
    required this.completedAt,
  });

  /// Create a completed workout from a scheduled workout
  factory CompletedWorkout.fromWorkout(
    Workout workout,
    DateTime scheduledDate, {
    List<PlannedExercise>? modifiedExercises,
  }) {
    return CompletedWorkout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scheduledWorkoutId: workout.id,
      workoutName: workout.name,
      iconCodePoint: workout.iconCodePoint,
      exercises: modifiedExercises ?? List.from(workout.exercises),
      scheduledDate: DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day),
      completedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduledWorkoutId': scheduledWorkoutId,
    'workoutName': workoutName,
    'iconCodePoint': iconCodePoint,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'scheduledDate': scheduledDate.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
  };

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) {
    return CompletedWorkout(
      id: json['id'] as String,
      scheduledWorkoutId: json['scheduledWorkoutId'] as String,
      workoutName: json['workoutName'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  CompletedWorkout copyWith({
    List<PlannedExercise>? exercises,
    DateTime? completedAt,
  }) {
    return CompletedWorkout(
      id: id,
      scheduledWorkoutId: scheduledWorkoutId,
      workoutName: workoutName,
      iconCodePoint: iconCodePoint,
      exercises: exercises ?? this.exercises,
      scheduledDate: scheduledDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
