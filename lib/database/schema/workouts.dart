import 'package:drift/drift.dart';

/// Workout table - defines workout templates
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/Workout.md
class Workouts extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Workout name - unique, 1-100 characters
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();

  /// Soft-delete flag
  BoolColumn get isDisabled => boolean().withDefault(const Constant(false))();

  /// Material Icons codePoint for workout icon
  IntColumn get iconCodePoint => integer()();
}
