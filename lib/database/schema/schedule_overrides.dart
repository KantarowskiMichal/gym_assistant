import 'package:drift/drift.dart';
import '../converters.dart';
import 'schedules.dart';
import 'exercises.dart';
import 'workout_exercises.dart';

/// ScheduleDayWorkoutOverride - customizes exercises for a specific date
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/ScheduleDayWorkoutOverride.md
class ScheduleDayWorkoutOverrides extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to Schedule - CASCADE on delete
  IntColumn get scheduleId => integer().references(Schedules, #id,
      onDelete: KeyAction.cascade, onUpdate: KeyAction.cascade)();

  /// The specific date this override applies to
  DateTimeColumn get date => dateTime()();
}

/// ScheduleDayWorkoutOverrideExercise - exercise in an override
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/ScheduleDayWorkoutOverrideExercise.md
class ScheduleDayWorkoutOverrideExercises extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to ScheduleDayWorkoutOverride - CASCADE on delete
  IntColumn get scheduleDayWorkoutOverrideId => integer().references(
      ScheduleDayWorkoutOverrides, #id,
      onDelete: KeyAction.cascade, onUpdate: KeyAction.cascade)();

  /// Foreign key to Exercise (for new exercises not in original workout)
  /// XOR constraint with workoutExerciseId: exactly one must be set
  /// (validated in repository)
  IntColumn get exerciseId =>
      integer().nullable().references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Foreign key to WorkoutExercise (for exercises from original workout)
  /// XOR constraint with exerciseId: exactly one must be set
  /// (validated in repository)
  IntColumn get workoutExerciseId => integer()
      .nullable()
      .references(WorkoutExercises, #id, onDelete: KeyAction.restrict)();

  /// Type: static (seconds) or dynamic (reps)
  TextColumn get type => text().map(const ExerciseTypeConverter())();

  /// Mode: reps, variableSets, or pyramid
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
