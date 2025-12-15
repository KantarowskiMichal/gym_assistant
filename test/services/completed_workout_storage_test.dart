import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_assistant/models/workout.dart';
import 'package:gym_assistant/models/exercise.dart';
import 'package:gym_assistant/models/completed_workout.dart';
import 'package:gym_assistant/services/completed_workout_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  CompletedWorkout createTestCompleted({
    String? id,
    String? scheduledWorkoutId,
    String? workoutName,
    DateTime? scheduledDate,
    DateTime? completedAt,
  }) {
    return CompletedWorkout(
      id: id ?? 'completed_id',
      scheduledWorkoutId: scheduledWorkoutId ?? 'scheduled_id',
      workoutName: workoutName ?? 'Test Workout',
      iconCodePoint: Icons.fitness_center.codePoint,
      exercises: [
        PlannedExercise(
          exerciseName: 'Push Ups',
          exerciseType: ExerciseType.dynamic,
          targetSets: 4,
          targetRepsOrDuration: 10,
        ),
      ],
      scheduledDate: scheduledDate ?? DateTime(2025, 1, 15),
      completedAt: completedAt ?? DateTime(2025, 1, 15, 10, 30),
    );
  }

  group('loadAll()', () {
    test('returns empty list when nothing stored', () async {
      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts, isEmpty);
    });

    test('returns all completed records', () async {
      final completed1 = createTestCompleted(id: 'completed_1');
      final completed2 = createTestCompleted(id: 'completed_2');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed1.toJson(), completed2.toJson()]),
      });

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(2));
    });

    test('handles JSON parse errors gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'completed_workouts': 'invalid json {{{',
      });

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts, isEmpty);
    });

    test('returns empty list for empty string', () async {
      SharedPreferences.setMockInitialValues({
        'completed_workouts': '',
      });

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts, isEmpty);
    });
  });

  group('addCompleted()', () {
    test('appends to list and saves', () async {
      final completed = createTestCompleted();

      await CompletedWorkoutStorage.addCompleted(completed);

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
      expect(workouts.first.workoutName, equals('Test Workout'));
    });

    test('appends to existing records', () async {
      final completed1 = createTestCompleted(id: 'first');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed1.toJson()]),
      });

      final completed2 = createTestCompleted(id: 'second');
      await CompletedWorkoutStorage.addCompleted(completed2);

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(2));
    });

    test('preserves completed workout data', () async {
      final completed = CompletedWorkout(
        id: 'preserve_test',
        scheduledWorkoutId: 'scheduled_123',
        workoutName: 'Preserved Workout',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Swimming',
            exerciseType: ExerciseType.dynamic,
            targetSets: 10,
            targetRepsOrDuration: 100,
            targetWeight: 0,
          ),
        ],
        scheduledDate: DateTime(2025, 2, 20),
        completedAt: DateTime(2025, 2, 20, 18, 45),
      );

      await CompletedWorkoutStorage.addCompleted(completed);

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.first.id, equals('preserve_test'));
      expect(workouts.first.scheduledWorkoutId, equals('scheduled_123'));
      expect(workouts.first.exercises.length, equals(1));
      expect(workouts.first.scheduledDate, equals(DateTime(2025, 2, 20)));
    });
  });

  group('updateCompleted()', () {
    test('updates existing by ID', () async {
      final original = createTestCompleted(id: 'update_test');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([original.toJson()]),
      });

      final updated = original.copyWith(
        exercises: [
          PlannedExercise(
            exerciseName: 'Updated Exercise',
            exerciseType: ExerciseType.static,
            targetSets: 3,
            targetRepsOrDuration: 60,
          ),
        ],
        completedAt: DateTime(2025, 1, 15, 15, 0),
      );

      await CompletedWorkoutStorage.updateCompleted(updated);

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
      expect(workouts.first.exercises.first.exerciseName, equals('Updated Exercise'));
      expect(workouts.first.completedAt.hour, equals(15));
    });

    test('does nothing if ID not found', () async {
      final original = createTestCompleted(id: 'existing_id');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([original.toJson()]),
      });

      final nonExistent = createTestCompleted(id: 'nonexistent_id');

      await CompletedWorkoutStorage.updateCompleted(nonExistent);

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
      expect(workouts.first.id, equals('existing_id'));
    });
  });

  group('deleteCompleted()', () {
    test('removes by ID from list', () async {
      final completed1 = createTestCompleted(id: 'to_delete');
      final completed2 = createTestCompleted(id: 'to_keep');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed1.toJson(), completed2.toJson()]),
      });

      await CompletedWorkoutStorage.deleteCompleted('to_delete');

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
      expect(workouts.first.id, equals('to_keep'));
    });

    test('other records unaffected', () async {
      final completed1 = createTestCompleted(
        id: 'one',
        workoutName: 'Workout One',
      );
      final completed2 = createTestCompleted(
        id: 'two',
        workoutName: 'Workout Two',
      );
      final completed3 = createTestCompleted(
        id: 'three',
        workoutName: 'Workout Three',
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([
          completed1.toJson(),
          completed2.toJson(),
          completed3.toJson(),
        ]),
      });

      await CompletedWorkoutStorage.deleteCompleted('two');

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(2));
      expect(workouts.any((w) => w.workoutName == 'Workout One'), isTrue);
      expect(workouts.any((w) => w.workoutName == 'Workout Two'), isFalse);
      expect(workouts.any((w) => w.workoutName == 'Workout Three'), isTrue);
    });

    test('does nothing if ID not found', () async {
      final completed = createTestCompleted(id: 'existing');

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      await CompletedWorkoutStorage.deleteCompleted('nonexistent');

      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
    });
  });

  group('findCompleted()', () {
    test('finds by scheduledWorkoutId + date combination', () async {
      final completed = createTestCompleted(
        id: 'found',
        scheduledWorkoutId: 'scheduled_abc',
        scheduledDate: DateTime(2025, 3, 10),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      final found = await CompletedWorkoutStorage.findCompleted(
        'scheduled_abc',
        DateTime(2025, 3, 10),
      );

      expect(found, isNotNull);
      expect(found!.id, equals('found'));
    });

    test('returns null if not found', () async {
      final completed = createTestCompleted(
        scheduledWorkoutId: 'scheduled_abc',
        scheduledDate: DateTime(2025, 3, 10),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      // Different scheduled workout ID
      var found = await CompletedWorkoutStorage.findCompleted(
        'different_id',
        DateTime(2025, 3, 10),
      );
      expect(found, isNull);

      // Different date
      found = await CompletedWorkoutStorage.findCompleted(
        'scheduled_abc',
        DateTime(2025, 3, 11),
      );
      expect(found, isNull);
    });

    test('date comparison ignores time component', () async {
      final completed = createTestCompleted(
        scheduledWorkoutId: 'scheduled_id',
        scheduledDate: DateTime(2025, 3, 15), // No time component
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      // Query with time component - should still find it
      final found = await CompletedWorkoutStorage.findCompleted(
        'scheduled_id',
        DateTime(2025, 3, 15, 14, 30, 45),
      );

      expect(found, isNotNull);
    });

    test('same scheduledWorkoutId on different dates returns correct one', () async {
      final completed1 = createTestCompleted(
        id: 'completed_day_1',
        scheduledWorkoutId: 'weekly_workout',
        scheduledDate: DateTime(2025, 1, 15),
      );
      final completed2 = createTestCompleted(
        id: 'completed_day_2',
        scheduledWorkoutId: 'weekly_workout',
        scheduledDate: DateTime(2025, 1, 22),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed1.toJson(), completed2.toJson()]),
      });

      var found = await CompletedWorkoutStorage.findCompleted(
        'weekly_workout',
        DateTime(2025, 1, 15),
      );
      expect(found?.id, equals('completed_day_1'));

      found = await CompletedWorkoutStorage.findCompleted(
        'weekly_workout',
        DateTime(2025, 1, 22),
      );
      expect(found?.id, equals('completed_day_2'));
    });
  });

  group('getCompletedForDate()', () {
    test('returns all completed for specific date', () async {
      final completed1 = createTestCompleted(
        id: 'same_day_1',
        scheduledWorkoutId: 'workout_a',
        scheduledDate: DateTime(2025, 3, 20),
      );
      final completed2 = createTestCompleted(
        id: 'same_day_2',
        scheduledWorkoutId: 'workout_b',
        scheduledDate: DateTime(2025, 3, 20),
      );
      final completed3 = createTestCompleted(
        id: 'different_day',
        scheduledWorkoutId: 'workout_c',
        scheduledDate: DateTime(2025, 3, 21),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([
          completed1.toJson(),
          completed2.toJson(),
          completed3.toJson(),
        ]),
      });

      final workouts = await CompletedWorkoutStorage.getCompletedForDate(
        DateTime(2025, 3, 20),
      );

      expect(workouts.length, equals(2));
      expect(workouts.any((w) => w.id == 'same_day_1'), isTrue);
      expect(workouts.any((w) => w.id == 'same_day_2'), isTrue);
      expect(workouts.any((w) => w.id == 'different_day'), isFalse);
    });

    test('date comparison ignores time', () async {
      final completed = createTestCompleted(
        scheduledDate: DateTime(2025, 3, 20),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      // Query with different time
      final workouts = await CompletedWorkoutStorage.getCompletedForDate(
        DateTime(2025, 3, 20, 23, 59, 59),
      );

      expect(workouts.length, equals(1));
    });

    test('returns empty list for date with no completions', () async {
      final completed = createTestCompleted(
        scheduledDate: DateTime(2025, 3, 20),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      final workouts = await CompletedWorkoutStorage.getCompletedForDate(
        DateTime(2025, 3, 21),
      );

      expect(workouts, isEmpty);
    });
  });

  group('isCompleted()', () {
    test('returns true when completed record exists', () async {
      final completed = createTestCompleted(
        scheduledWorkoutId: 'test_scheduled',
        scheduledDate: DateTime(2025, 4, 1),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      final isComplete = await CompletedWorkoutStorage.isCompleted(
        'test_scheduled',
        DateTime(2025, 4, 1),
      );

      expect(isComplete, isTrue);
    });

    test('returns false when no record', () async {
      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([]),
      });

      final isComplete = await CompletedWorkoutStorage.isCompleted(
        'any_id',
        DateTime(2025, 4, 1),
      );

      expect(isComplete, isFalse);
    });

    test('returns false for wrong date', () async {
      final completed = createTestCompleted(
        scheduledWorkoutId: 'test_scheduled',
        scheduledDate: DateTime(2025, 4, 1),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      final isComplete = await CompletedWorkoutStorage.isCompleted(
        'test_scheduled',
        DateTime(2025, 4, 2), // Wrong date
      );

      expect(isComplete, isFalse);
    });

    test('returns false for wrong scheduledWorkoutId', () async {
      final completed = createTestCompleted(
        scheduledWorkoutId: 'test_scheduled',
        scheduledDate: DateTime(2025, 4, 1),
      );

      SharedPreferences.setMockInitialValues({
        'completed_workouts': jsonEncode([completed.toJson()]),
      });

      final isComplete = await CompletedWorkoutStorage.isCompleted(
        'different_id', // Wrong ID
        DateTime(2025, 4, 1),
      );

      expect(isComplete, isFalse);
    });
  });

  group('Data persistence', () {
    test('completed workouts persist independently of templates', () async {
      // This documents that completed workouts are stored separately
      // and survive template/scheduled workout deletion

      final completed = createTestCompleted(
        scheduledWorkoutId: 'deleted_scheduled_workout',
        workoutName: 'Workout That Was Deleted',
      );

      await CompletedWorkoutStorage.addCompleted(completed);

      // Even though the scheduledWorkoutId might not exist anymore,
      // the completed record is preserved
      final workouts = await CompletedWorkoutStorage.loadAll();
      expect(workouts.length, equals(1));
      expect(workouts.first.workoutName, equals('Workout That Was Deleted'));
    });
  });
}
