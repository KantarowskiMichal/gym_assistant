import 'package:drift/drift.dart';
import '../converters.dart';
import 'workouts.dart';
import 'exercises.dart';

/// CompletedWorkout - historical record of completed workout
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/CompletedWorkout.md
class CompletedWorkouts extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to Workout - RESTRICT on delete (preserve history)
  IntColumn get workoutId => integer()
      .references(Workouts, #id, onDelete: KeyAction.restrict)();

  /// The date the workout was completed
  DateTimeColumn get date => dateTime()();
}

/// CompletedExercise - historical record of completed exercise
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/CompletedExercise.md
class CompletedExercises extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to CompletedWorkout - CASCADE on delete
  IntColumn get completedWorkoutId => integer().references(CompletedWorkouts, #id,
      onDelete: KeyAction.cascade, onUpdate: KeyAction.cascade)();

  /// Foreign key to Exercise - RESTRICT on delete (preserve history)
  IntColumn get exerciseId => integer()
      .references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Type: static (seconds) or dynamic (reps)
  TextColumn get type => text().map(const ExerciseTypeConverter())();

  /// Mode: reps, variableSets, or pyramid
  TextColumn get mode => text().map(const ExerciseModeConverter())();

  /// Position of exercise in workout list (0 = first), preserved for statistics
  /// Constraint: >= 0 (validated in repository)
  IntColumn get orderIndex => integer()();

  /// JSON array of sets actually performed: [{value, weight, rest}, ...]
  /// Constraint: length >= 1 (validated in repository)
  TextColumn get sets => text().map(const ExerciseSetsConverter())();

  /// Rest after exercise in seconds, nullable
  /// Constraint: >= 1 when set, 0 stored as null (validated in repository)
  IntColumn get restAfterExercise => integer().nullable()();
}
