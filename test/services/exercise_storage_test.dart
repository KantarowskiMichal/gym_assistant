import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_assistant/models/exercise.dart';
import 'package:gym_assistant/services/exercise_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('loadCustomExercises()', () {
    test('returns empty list when nothing stored', () async {
      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises, isEmpty);
    });

    test('returns stored custom exercises', () async {
      final customExercise = Exercise.create(
        name: 'Custom Exercise',
        type: ExerciseType.dynamic,
        defaultSets: 3,
        defaultRepsOrDuration: 15,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customExercise.toJson()]),
      });

      final exercises = await ExerciseStorage.loadCustomExercises();

      expect(exercises.length, equals(1));
      expect(exercises.first.name, equals('Custom Exercise'));
      expect(exercises.first.defaultSets, equals(3));
    });

    test('handles JSON parse errors gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'custom_exercises': 'invalid json {{{',
      });

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises, isEmpty);
    });

    test('returns empty list for empty string', () async {
      SharedPreferences.setMockInitialValues({
        'custom_exercises': '',
      });

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises, isEmpty);
    });
  });

  group('getAllExercises()', () {
    test('returns defaults when no custom exercises', () async {
      final exercises = await ExerciseStorage.getAllExercises();

      expect(exercises.length, equals(Exercise.defaults.length));
      expect(exercises.any((e) => e.name == 'Pull Ups'), isTrue);
      expect(exercises.any((e) => e.name == 'Push Ups'), isTrue);
      expect(exercises.any((e) => e.name == 'Planche'), isTrue);
    });

    test('returns custom + defaults combined', () async {
      final customExercise = Exercise.create(
        name: 'My Custom Exercise',
        type: ExerciseType.dynamic,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customExercise.toJson()]),
      });

      final exercises = await ExerciseStorage.getAllExercises();

      expect(exercises.length, equals(Exercise.defaults.length + 1));
      expect(exercises.any((e) => e.name == 'My Custom Exercise'), isTrue);
      expect(exercises.any((e) => e.name == 'Pull Ups'), isTrue);
    });

    test('custom exercise overrides default with same name (case-insensitive)', () async {
      // Create a custom "Pull Ups" with different defaults
      final customPullUps = Exercise.create(
        name: 'Pull Ups',
        type: ExerciseType.dynamic,
        defaultSets: 5,
        defaultRepsOrDuration: 8,
        defaultWeight: 10.0,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customPullUps.toJson()]),
      });

      final exercises = await ExerciseStorage.getAllExercises();

      // Should still have same total count (custom replaces default)
      expect(exercises.length, equals(Exercise.defaults.length));

      // Find Pull Ups and verify it's the custom one
      final pullUps = exercises.firstWhere((e) => e.name == 'Pull Ups');
      expect(pullUps.defaultSets, equals(5));
      expect(pullUps.defaultRepsOrDuration, equals(8));
      expect(pullUps.defaultWeight, equals(10.0));
      expect(pullUps.isCustom, isTrue);
    });

    test('override is case-insensitive', () async {
      final customPullUps = Exercise.create(
        name: 'PULL UPS', // Different case
        type: ExerciseType.dynamic,
        defaultSets: 6,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customPullUps.toJson()]),
      });

      final exercises = await ExerciseStorage.getAllExercises();

      // Should override the default "Pull Ups"
      expect(exercises.length, equals(Exercise.defaults.length));
      expect(exercises.any((e) => e.name == 'PULL UPS'), isTrue);
      expect(exercises.where((e) => e.name.toLowerCase() == 'pull ups').length, equals(1));
    });

    test('results are sorted alphabetically', () async {
      final customA = Exercise.create(name: 'Aardvark Exercise', type: ExerciseType.dynamic);
      final customZ = Exercise.create(name: 'Zebra Exercise', type: ExerciseType.dynamic);

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customZ.toJson(), customA.toJson()]),
      });

      final exercises = await ExerciseStorage.getAllExercises();

      // First exercise should be "Aardvark Exercise"
      expect(exercises.first.name, equals('Aardvark Exercise'));

      // Verify list is sorted
      for (var i = 0; i < exercises.length - 1; i++) {
        expect(
          exercises[i].name.toLowerCase().compareTo(exercises[i + 1].name.toLowerCase()),
          lessThanOrEqualTo(0),
        );
      }
    });
  });

  group('findByName()', () {
    test('case-insensitive matching', () async {
      final exercise = await ExerciseStorage.findByName('PULL UPS');
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Pull Ups'));
    });

    test('returns custom exercise if exists', () async {
      final customPullUps = Exercise.create(
        name: 'Pull Ups',
        type: ExerciseType.dynamic,
        defaultSets: 6,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customPullUps.toJson()]),
      });

      final exercise = await ExerciseStorage.findByName('Pull Ups');

      expect(exercise, isNotNull);
      expect(exercise!.defaultSets, equals(6));
      expect(exercise.isCustom, isTrue);
    });

    test('returns default if no custom override', () async {
      final exercise = await ExerciseStorage.findByName('Push Ups');

      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Push Ups'));
      expect(exercise.isCustom, isFalse);
    });

    test('returns null if not found at all', () async {
      final exercise = await ExerciseStorage.findByName('Nonexistent Exercise');
      expect(exercise, isNull);
    });
  });

  group('addExercise()', () {
    test('returns false if name already exists in custom exercises (case-insensitive)', () async {
      final exercise1 = Exercise.create(name: 'My Exercise', type: ExerciseType.dynamic);

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise1.toJson()]),
      });

      final exercise2 = Exercise.create(name: 'MY EXERCISE', type: ExerciseType.static);
      final result = await ExerciseStorage.addExercise(exercise2);

      expect(result, isFalse);

      // Verify original is unchanged
      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
      expect(exercises.first.type, equals(ExerciseType.dynamic));
    });

    test('returns true and saves for unique name', () async {
      final exercise = Exercise.create(
        name: 'Brand New Exercise',
        type: ExerciseType.static,
        defaultSets: 3,
      );

      final result = await ExerciseStorage.addExercise(exercise);

      expect(result, isTrue);

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
      expect(exercises.first.name, equals('Brand New Exercise'));
    });

    test('can add exercise with same name as default (creates override)', () async {
      final customPullUps = Exercise.create(
        name: 'Pull Ups', // Same as default
        type: ExerciseType.dynamic,
        defaultSets: 5,
        defaultRepsOrDuration: 12,
      );

      final result = await ExerciseStorage.addExercise(customPullUps);

      expect(result, isTrue);

      // Verify it's stored
      final customExercises = await ExerciseStorage.loadCustomExercises();
      expect(customExercises.length, equals(1));
      expect(customExercises.first.defaultSets, equals(5));

      // Verify it overrides in getAllExercises
      final allExercises = await ExerciseStorage.getAllExercises();
      final pullUps = allExercises.firstWhere((e) => e.name == 'Pull Ups');
      expect(pullUps.defaultSets, equals(5));
      expect(pullUps.isCustom, isTrue);
    });

    test('appends to existing custom exercises', () async {
      final exercise1 = Exercise.create(name: 'Exercise 1', type: ExerciseType.dynamic);
      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise1.toJson()]),
      });

      final exercise2 = Exercise.create(name: 'Exercise 2', type: ExerciseType.static);
      await ExerciseStorage.addExercise(exercise2);

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(2));
    });
  });

  group('updateExercise()', () {
    test('updates existing exercise by ID', () async {
      final exercise = Exercise.create(
        name: 'Original Name',
        type: ExerciseType.dynamic,
        defaultSets: 4,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise.toJson()]),
      });

      final updated = exercise.copyWith(name: 'Updated Name', defaultSets: 5);
      final result = await ExerciseStorage.updateExercise(updated);

      expect(result, isTrue);

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
      expect(exercises.first.name, equals('Updated Name'));
      expect(exercises.first.defaultSets, equals(5));
    });

    test('returns false if new name conflicts with another custom exercise', () async {
      // Use explicit IDs to avoid timing issues
      final exercise1 = Exercise(
        id: 'test_conflict_id_1',
        name: 'Conflict Exercise 1',
        type: ExerciseType.dynamic,
      );
      final exercise2 = Exercise(
        id: 'test_conflict_id_2',
        name: 'Conflict Exercise 2',
        type: ExerciseType.dynamic,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise1.toJson(), exercise2.toJson()]),
      });

      // Try to rename exercise1 to exercise2's name
      final updated = exercise1.copyWith(name: 'Conflict Exercise 2');
      final result = await ExerciseStorage.updateExercise(updated);

      expect(result, isFalse);

      // Verify nothing changed
      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.any((e) => e.name == 'Conflict Exercise 1'), isTrue);
    });

    test('adds as new if ID not found (override scenario)', () async {
      // Start with no custom exercises
      SharedPreferences.setMockInitialValues({});

      // Create exercise with ID that doesn't exist in custom
      final newExercise = Exercise(
        id: 'new_unique_id',
        name: 'New Exercise',
        type: ExerciseType.dynamic,
      );

      final result = await ExerciseStorage.updateExercise(newExercise);

      expect(result, isTrue);

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
      expect(exercises.first.name, equals('New Exercise'));
    });
  });

  group('deleteExercise()', () {
    test('removes exercise from custom list', () async {
      // Use explicit IDs
      final exercise1 = Exercise(
        id: 'delete_test_id_1',
        name: 'Delete Exercise 1',
        type: ExerciseType.dynamic,
      );
      final exercise2 = Exercise(
        id: 'delete_test_id_2',
        name: 'Delete Exercise 2',
        type: ExerciseType.dynamic,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise1.toJson(), exercise2.toJson()]),
      });

      // Verify both exist
      var exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(2));

      await ExerciseStorage.deleteExercise(exercise1.id);

      exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
      expect(exercises.first.name, equals('Delete Exercise 2'));
    });

    test('does not affect hardcoded defaults', () async {
      // Try to delete a default exercise ID
      await ExerciseStorage.deleteExercise('default_pull_ups');

      // Default should still be available
      final allExercises = await ExerciseStorage.getAllExercises();
      expect(allExercises.any((e) => e.name == 'Pull Ups'), isTrue);
    });

    test('does nothing if ID not found', () async {
      final exercise = Exercise.create(name: 'Test', type: ExerciseType.dynamic);

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise.toJson()]),
      });

      await ExerciseStorage.deleteExercise('nonexistent_id');

      final exercises = await ExerciseStorage.loadCustomExercises();
      expect(exercises.length, equals(1));
    });

    test('removing override restores default', () async {
      // Add a custom "Pull Ups" that overrides default
      final customPullUps = Exercise.create(
        name: 'Pull Ups',
        type: ExerciseType.dynamic,
        defaultSets: 6,
      );

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([customPullUps.toJson()]),
      });

      // Verify custom is being used
      var pullUps = await ExerciseStorage.findByName('Pull Ups');
      expect(pullUps!.defaultSets, equals(6));

      // Delete the custom override
      await ExerciseStorage.deleteExercise(customPullUps.id);

      // Default should now be used
      pullUps = await ExerciseStorage.findByName('Pull Ups');
      expect(pullUps!.defaultSets, equals(4)); // Default value
      expect(pullUps.isCustom, isFalse);
    });
  });

  group('nameExists()', () {
    test('returns true if name exists', () async {
      final exists = await ExerciseStorage.nameExists('Pull Ups');
      expect(exists, isTrue);
    });

    test('returns false if name does not exist', () async {
      final exists = await ExerciseStorage.nameExists('Nonexistent');
      expect(exists, isFalse);
    });

    test('case-insensitive check', () async {
      final exists = await ExerciseStorage.nameExists('PULL UPS');
      expect(exists, isTrue);
    });

    test('excludes specified ID', () async {
      final exercise = Exercise.create(name: 'Test Exercise', type: ExerciseType.dynamic);

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([exercise.toJson()]),
      });

      // Without exclusion - should find it
      var exists = await ExerciseStorage.nameExists('Test Exercise');
      expect(exists, isTrue);

      // With exclusion - should not find it
      exists = await ExerciseStorage.nameExists('Test Exercise', excludeId: exercise.id);
      expect(exists, isFalse);
    });
  });

  group('getAllNames()', () {
    test('returns list of exercise names', () async {
      final names = await ExerciseStorage.getAllNames();

      expect(names, contains('Pull Ups'));
      expect(names, contains('Push Ups'));
      expect(names, contains('Planche'));
    });

    test('includes custom exercise names', () async {
      final custom = Exercise.create(name: 'Custom Name', type: ExerciseType.dynamic);

      SharedPreferences.setMockInitialValues({
        'custom_exercises': jsonEncode([custom.toJson()]),
      });

      final names = await ExerciseStorage.getAllNames();

      expect(names, contains('Custom Name'));
    });
  });
}
