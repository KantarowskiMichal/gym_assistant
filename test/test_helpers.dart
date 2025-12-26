import 'package:drift/native.dart';
import 'package:gym_assistant/database/database.dart';
import 'package:gym_assistant/database/converters.dart';

/// Creates an in-memory database for testing (without seeding default exercises)
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

// Helper to create sample ExerciseSet data
List<ExerciseSet> createSampleSets({
  int count = 3,
  int value = 10,
  double weight = 0,
  int? rest = 90,
}) {
  return List.generate(
    count,
    (i) => ExerciseSet(
      value: value,
      weight: weight,
      rest: i == count - 1 ? null : rest, // Last set has no rest
    ),
  );
}

// Sample data for testing
const sampleExerciseName = 'Test Exercise';
const sampleWorkoutName = 'Test Workout';
const sampleIconCodePoint = 0xe1b5; // Icons.fitness_center

// DateTime helpers
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime tomorrow() => today().add(const Duration(days: 1));
DateTime yesterday() => today().subtract(const Duration(days: 1));
DateTime daysFromNow(int days) => today().add(Duration(days: days));
