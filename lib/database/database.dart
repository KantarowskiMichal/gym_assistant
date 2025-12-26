import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'schema/exercises.dart';
import 'schema/workouts.dart';
import 'schema/workout_exercises.dart';
import 'schema/schedules.dart';
import 'schema/schedule_overrides.dart';
import 'schema/completed_workouts.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Exercises,
  Workouts,
  WorkoutExercises,
  Schedules,
  ScheduleDayWorkoutOverrides,
  ScheduleDayWorkoutOverrideExercises,
  CompletedWorkouts,
  CompletedExercises,
])
class AppDatabase extends _$AppDatabase {
  final bool _seedData;

  /// Default constructor for production use
  AppDatabase()
      : _seedData = true,
        super(_openConnection());

  /// Constructor for testing with a custom executor (e.g., in-memory database)
  /// Set [seedData] to false to skip seeding default exercises
  AppDatabase.forTesting(super.executor, {bool seedData = false})
      : _seedData = seedData;

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gym_assistant_db');
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        if (_seedData) {
          await _seedDefaultExercises();
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
      beforeOpen: (details) async {
        // Enable foreign key constraints
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Seeds the database with default exercises
  Future<void> _seedDefaultExercises() async {
    final defaultExercises = [
      // Dynamic (reps) exercises
      ExercisesCompanion.insert(
        name: 'Pull Ups',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Push Ups',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Dips',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Leg Press',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Bench Press',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Dead Lift',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: null),
        ],
      ),
      // Static (seconds) exercises
      ExercisesCompanion.insert(
        name: 'Planche',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Dead Hang',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Front Lever',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: null),
        ],
      ),
      ExercisesCompanion.insert(
        name: 'Back Lever',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        isDefault: const Value(true),
        sets: [
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: 90),
          const ExerciseSet(value: 30, weight: 0, rest: null),
        ],
      ),
    ];

    for (final exercise in defaultExercises) {
      await into(exercises).insert(exercise);
    }
  }
}
