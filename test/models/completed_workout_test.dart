import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/models/workout.dart';
import 'package:gym_assistant/models/exercise.dart';
import 'package:gym_assistant/models/completed_workout.dart';

void main() {
  group('CompletedWorkout.fromWorkout()', () {
    late Workout sourceWorkout;

    setUp(() {
      sourceWorkout = Workout(
        id: 'source_workout_id',
        name: 'Test Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Push Ups',
            mode: ExerciseMode.reps,
            targetSets: 4,
            targetReps: 10,
          ),
          PlannedExercise(
            exerciseName: 'Plank',
            mode: ExerciseMode.static,
            targetSets: 3,
            targetSeconds: 60,
          ),
        ],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.weekly,
      );
    });

    test('generates timestamp-based ID', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.id, isNotEmpty);
      expect(int.tryParse(completed.id), isNotNull);
      final timestamp = int.parse(completed.id);
      expect(timestamp, greaterThan(1577836800000)); // Jan 1, 2020
    });

    test('copies workout name from source', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.workoutName, equals('Test Workout'));
    });

    test('copies icon from source', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.iconCodePoint, equals(Icons.fitness_center.codePoint));
    });

    test('stores scheduledWorkoutId reference', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.scheduledWorkoutId, equals('source_workout_id'));
    });

    test('uses workout exercises by default', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.exercises.length, equals(2));
      expect(completed.exercises[0].exerciseName, equals('Push Ups'));
      expect(completed.exercises[1].exerciseName, equals('Plank'));
    });

    test('uses modifiedExercises when provided', () {
      final modifiedExercises = [
        PlannedExercise(
          exerciseName: 'Modified Exercise',
          mode: ExerciseMode.reps,
          targetSets: 5,
          targetReps: 15,
          targetWeight: 20.0,
        ),
      ];

      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
        modifiedExercises: modifiedExercises,
      );

      expect(completed.exercises.length, equals(1));
      expect(completed.exercises[0].exerciseName, equals('Modified Exercise'));
      expect(completed.exercises[0].targetSets, equals(5));
    });

    test('normalizes scheduledDate (strips time)', () {
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15, 14, 30, 45, 123),
      );

      expect(completed.scheduledDate, equals(DateTime(2025, 1, 15)));
      expect(completed.scheduledDate.hour, equals(0));
      expect(completed.scheduledDate.minute, equals(0));
      expect(completed.scheduledDate.second, equals(0));
    });

    test('sets completedAt to current time', () {
      final before = DateTime.now();
      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );
      final after = DateTime.now();

      expect(completed.completedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(completed.completedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('CompletedWorkout.copyWith()', () {
    late CompletedWorkout original;

    setUp(() {
      original = CompletedWorkout(
        id: 'original_id',
        scheduledWorkoutId: 'scheduled_id',
        workoutName: 'Original Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Push Ups',
            mode: ExerciseMode.reps,
            targetSets: 4,
            targetReps: 10,
          ),
        ],
        scheduledDate: DateTime(2025, 1, 15),
        completedAt: DateTime(2025, 1, 15, 10, 30),
      );
    });

    test('returns new instance with updated exercises', () {
      final newExercises = [
        PlannedExercise(
          exerciseName: 'New Exercise',
          mode: ExerciseMode.static,
          targetSets: 3,
          targetSeconds: 45,
        ),
      ];

      final copy = original.copyWith(exercises: newExercises);

      expect(copy.exercises.length, equals(1));
      expect(copy.exercises[0].exerciseName, equals('New Exercise'));
      expect(identical(copy, original), isFalse);
    });

    test('preserves unchanged fields', () {
      final newExercises = [
        PlannedExercise(
          exerciseName: 'New Exercise',
          mode: ExerciseMode.reps,
          targetSets: 4,
          targetReps: 10,
        ),
      ];

      final copy = original.copyWith(exercises: newExercises);

      expect(copy.id, equals(original.id));
      expect(copy.scheduledWorkoutId, equals(original.scheduledWorkoutId));
      expect(copy.workoutName, equals(original.workoutName));
      expect(copy.iconCodePoint, equals(original.iconCodePoint));
      expect(copy.scheduledDate, equals(original.scheduledDate));
      expect(copy.completedAt, equals(original.completedAt));
    });

    test('updates completedAt when provided', () {
      final newCompletedAt = DateTime(2025, 1, 15, 15, 45);

      final copy = original.copyWith(completedAt: newCompletedAt);

      expect(copy.completedAt, equals(newCompletedAt));
      expect(copy.exercises, equals(original.exercises));
    });

    test('can update both exercises and completedAt', () {
      final newExercises = [
        PlannedExercise(
          exerciseName: 'Updated Exercise',
          mode: ExerciseMode.reps,
          targetSets: 5,
          targetReps: 12,
          targetWeight: 15.0,
        ),
      ];
      final newCompletedAt = DateTime(2025, 1, 16, 9, 0);

      final copy = original.copyWith(
        exercises: newExercises,
        completedAt: newCompletedAt,
      );

      expect(copy.exercises.length, equals(1));
      expect(copy.exercises[0].exerciseName, equals('Updated Exercise'));
      expect(copy.completedAt, equals(newCompletedAt));
    });
  });

  group('CompletedWorkout serialization', () {
    test('toJson contains all fields', () {
      final completed = CompletedWorkout(
        id: 'test_id',
        scheduledWorkoutId: 'scheduled_id',
        workoutName: 'Test Workout',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Swimming',
            mode: ExerciseMode.reps,
            targetSets: 10,
            targetReps: 100,
          ),
        ],
        scheduledDate: DateTime(2025, 1, 20),
        completedAt: DateTime(2025, 1, 20, 18, 30),
      );

      final json = completed.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['scheduledWorkoutId'], equals('scheduled_id'));
      expect(json['workoutName'], equals('Test Workout'));
      expect(json['iconCodePoint'], equals(Icons.pool.codePoint));
      expect(json['exercises'], isA<List>());
      expect((json['exercises'] as List).length, equals(1));
      expect(json['scheduledDate'], equals('2025-01-20T00:00:00.000'));
      expect(json['completedAt'], contains('2025-01-20'));
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 'parsed_id',
        'scheduledWorkoutId': 'scheduled_ref',
        'workoutName': 'Parsed Workout',
        'iconCodePoint': Icons.directions_run.codePoint,
        'exercises': [
          {
            'exerciseName': 'Running',
            'mode': 'reps',
            'targetSets': 1,
            'targetReps': 30,
            'targetWeight': 0,
          },
        ],
        'scheduledDate': '2025-02-01T00:00:00.000',
        'completedAt': '2025-02-01T07:00:00.000',
      };

      final completed = CompletedWorkout.fromJson(json);

      expect(completed.id, equals('parsed_id'));
      expect(completed.scheduledWorkoutId, equals('scheduled_ref'));
      expect(completed.workoutName, equals('Parsed Workout'));
      expect(completed.iconCodePoint, equals(Icons.directions_run.codePoint));
      expect(completed.exercises.length, equals(1));
      expect(completed.exercises[0].exerciseName, equals('Running'));
      expect(completed.scheduledDate, equals(DateTime(2025, 2, 1)));
      expect(completed.completedAt, equals(DateTime(2025, 2, 1, 7, 0)));
    });

    test('toJson -> fromJson roundtrip preserves all fields', () {
      final original = CompletedWorkout(
        id: 'roundtrip_id',
        scheduledWorkoutId: 'scheduled_roundtrip',
        workoutName: 'Roundtrip Workout',
        iconCodePoint: Icons.star.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Exercise 1',
            mode: ExerciseMode.reps,
            targetSets: 4,
            targetReps: 10,
            targetWeight: 25.5,
          ),
          PlannedExercise(
            exerciseName: 'Exercise 2',
            mode: ExerciseMode.static,
            targetSets: 3,
            targetSeconds: 45,
          ),
        ],
        scheduledDate: DateTime(2025, 3, 15),
        completedAt: DateTime(2025, 3, 15, 19, 45, 30),
      );

      final json = original.toJson();
      final restored = CompletedWorkout.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.scheduledWorkoutId, equals(original.scheduledWorkoutId));
      expect(restored.workoutName, equals(original.workoutName));
      expect(restored.iconCodePoint, equals(original.iconCodePoint));
      expect(restored.exercises.length, equals(original.exercises.length));
      expect(restored.exercises[0].exerciseName, equals(original.exercises[0].exerciseName));
      expect(restored.exercises[1].exerciseName, equals(original.exercises[1].exerciseName));
      expect(restored.scheduledDate, equals(original.scheduledDate));
      expect(restored.completedAt, equals(original.completedAt));
    });

    test('DateTime fields serialize correctly', () {
      final completed = CompletedWorkout(
        id: 'datetime_test',
        scheduledWorkoutId: 'scheduled',
        workoutName: 'DateTime Test',
        iconCodePoint: Icons.timer.codePoint,
        exercises: [],
        scheduledDate: DateTime(2025, 12, 31),
        completedAt: DateTime(2025, 12, 31, 23, 59, 59),
      );

      final json = completed.toJson();
      final restored = CompletedWorkout.fromJson(json);

      expect(restored.scheduledDate.year, equals(2025));
      expect(restored.scheduledDate.month, equals(12));
      expect(restored.scheduledDate.day, equals(31));
      expect(restored.completedAt.hour, equals(23));
      expect(restored.completedAt.minute, equals(59));
      expect(restored.completedAt.second, equals(59));
    });

    test('exercises list is preserved in roundtrip', () {
      final exercises = [
        PlannedExercise(
          exerciseName: 'Pull Ups',
          mode: ExerciseMode.reps,
          targetSets: 4,
          targetReps: 8,
          targetWeight: 10.0,
        ),
        PlannedExercise(
          exerciseName: 'Dead Hang',
          mode: ExerciseMode.static,
          targetSets: 3,
          targetSeconds: 30,
        ),
        PlannedExercise(
          exerciseName: 'Chin Ups',
          mode: ExerciseMode.reps,
          targetSets: 3,
          targetReps: 6,
          targetWeight: 5.0,
        ),
      ];

      final original = CompletedWorkout(
        id: 'exercises_test',
        scheduledWorkoutId: 'scheduled',
        workoutName: 'Pull Day',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: exercises,
        scheduledDate: DateTime(2025, 1, 15),
        completedAt: DateTime(2025, 1, 15, 18, 0),
      );

      final json = original.toJson();
      final restored = CompletedWorkout.fromJson(json);

      expect(restored.exercises.length, equals(3));

      for (var i = 0; i < exercises.length; i++) {
        expect(restored.exercises[i].exerciseName, equals(exercises[i].exerciseName));
        expect(restored.exercises[i].mode, equals(exercises[i].mode));
        expect(restored.exercises[i].targetSets, equals(exercises[i].targetSets));
        expect(restored.exercises[i].targetWeight, equals(exercises[i].targetWeight));
      }
    });
  });

  group('CompletedWorkout preserves data independently', () {
    test('workoutName is stored even after source could be deleted', () {
      final completed = CompletedWorkout(
        id: 'preserved_id',
        scheduledWorkoutId: 'deleted_workout_id',
        workoutName: 'Preserved Workout Name',
        iconCodePoint: Icons.favorite.codePoint,
        exercises: [],
        scheduledDate: DateTime(2025, 1, 15),
        completedAt: DateTime(2025, 1, 15, 10, 0),
      );

      expect(completed.workoutName, equals('Preserved Workout Name'));
      expect(completed.iconCodePoint, equals(Icons.favorite.codePoint));
    });

    test('exercises are copies, not references', () {
      final sourceExercises = [
        PlannedExercise(
          exerciseName: 'Original',
          mode: ExerciseMode.reps,
          targetSets: 4,
          targetReps: 10,
        ),
      ];

      final sourceWorkout = Workout(
        id: 'source_id',
        name: 'Source',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: sourceExercises,
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final completed = CompletedWorkout.fromWorkout(
        sourceWorkout,
        DateTime(2025, 1, 15),
      );

      expect(completed.exercises.length, equals(1));
      expect(completed.exercises[0].exerciseName, equals('Original'));
    });
  });
}
