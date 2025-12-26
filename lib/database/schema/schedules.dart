import 'package:drift/drift.dart';
import '../converters.dart';
import 'workouts.dart';

/// Schedule table - defines when workouts occur
/// Documentation: See /ProgrammingNotes/gym_assistant/Data structure/Schedule.md
class Schedules extends Table {
  /// Primary key, auto-increment
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to Workout - RESTRICT on delete (can't delete scheduled workouts)
  IntColumn get workoutId => integer()
      .references(Workouts, #id, onDelete: KeyAction.restrict)();

  /// First occurrence date
  DateTimeColumn get startDate => dateTime()();

  /// How the workout repeats: oneOff, weekly, or offset
  TextColumn get recurrenceType =>
      text().map(const RecurrenceTypeConverter())();

  /// Days between occurrences for offset recurrence
  /// Constraint: >= 1 when recurrenceType is offset (validated in repository)
  IntColumn get offsetDays => integer().nullable()();
}
