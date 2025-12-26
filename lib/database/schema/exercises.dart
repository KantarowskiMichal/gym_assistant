import 'package:drift/drift.dart';
import '../converters.dart';

/// Exercise table - defines exercise templates
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/Exercise.md
class Exercises extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Exercise name - unique, 1-100 characters
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();

  /// Type: static (seconds) or dynamic (reps)
  TextColumn get type => text().map(const ExerciseTypeConverter())();

  /// Mode: reps, variableSets, or pyramid - determines UI flow
  TextColumn get mode => text().map(const ExerciseModeConverter())();

  /// Whether this is a default (seeded) exercise
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Soft-delete flag
  BoolColumn get isDisabled => boolean().withDefault(const Constant(false))();

  /// JSON array of sets: [{value, weight, rest}, ...]
  /// Constraint: length >= 1 (validated in repository)
  TextColumn get sets => text().map(const ExerciseSetsConverter())();

  /// Rest after exercise in seconds, nullable
  /// Constraint: >= 1 when set, 0 stored as null (validated in repository)
  IntColumn get restAfterExercise => integer().nullable()();
}
