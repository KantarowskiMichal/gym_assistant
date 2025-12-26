import 'package:drift/drift.dart';
import '../converters.dart';
import 'exercises.dart';
import 'workouts.dart';

/// WorkoutExercise table - links exercises to workouts with configuration
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/WorkoutExercise.md
class WorkoutExercises extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to Workout - RESTRICT on delete (can't delete workout with exercises)
  IntColumn get workoutId => integer()
      .references(Workouts, #id, onDelete: KeyAction.restrict)();

  /// Foreign key to Exercise - RESTRICT on delete (can't delete used exercises)
  IntColumn get exerciseId => integer()
      .references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Type copied from exercise at time of adding (for historical accuracy)
  TextColumn get type => text().map(const ExerciseTypeConverter())();

  /// Mode copied from exercise at time of adding
  TextColumn get mode => text().map(const ExerciseModeConverter())();

  /// Position in workout list (0 = first)
  /// Constraint: >= 0 (validated in repository)
  IntColumn get orderIndex => integer()();

  /// JSON array of sets: [{value, weight, rest}, ...]
  /// Constraint: length >= 1 (validated in repository)
  TextColumn get sets => text().map(const ExerciseSetsConverter())();

  /// Rest after exercise in seconds, nullable
  /// Constraint: >= 1 when set, 0 stored as null (validated in repository)
  IntColumn get restAfterExercise => integer().nullable()();
}
