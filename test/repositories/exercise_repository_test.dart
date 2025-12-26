import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/database/database.dart';
import 'package:gym_assistant/database/converters.dart';
import 'package:gym_assistant/database/validators.dart';
import 'package:gym_assistant/repositories/exercise_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository repository;

  setUp(() async {
    db = createTestDatabase();
    repository = ExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ExerciseRepository - CRUD', () {
    test('insert should create exercise with auto-increment id', () async {
      final id = await repository.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      expect(id, greaterThan(0));

      final exercise = await repository.getById(id);
      expect(exercise, isNotNull);
      expect(exercise!.name, equals('Test Exercise'));
      expect(exercise.type, equals(ExerciseType.dynamic));
      expect(exercise.mode, equals(ExerciseMode.reps));
      expect(exercise.isDefault, isFalse);
      expect(exercise.isDisabled, isFalse);
    });

    test('insert should set isDefault flag correctly', () async {
      final id = await repository.insert(
        name: 'Default Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: true,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.isDefault, isTrue);
    });

    test('insert should store restAfterExercise correctly', () async {
      final id = await repository.insert(
        name: 'Exercise With Rest',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        restAfterExercise: 120,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.restAfterExercise, equals(120));
    });

    test('insert should convert 0 restAfterExercise to null', () async {
      final id = await repository.insert(
        name: 'Exercise Zero Rest',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        restAfterExercise: 0,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.restAfterExercise, isNull);
    });

    test('getById should return null for non-existent id', () async {
      final exercise = await repository.getById(999);
      expect(exercise, isNull);
    });

    test('update should modify exercise', () async {
      final id = await repository.insert(
        name: 'Original Name',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final original = await repository.getById(id);
      final updated = original!.copyWith(name: 'Updated Name');

      final success = await repository.update(updated);
      expect(success, isTrue);

      final fetched = await repository.getById(id);
      expect(fetched!.name, equals('Updated Name'));
    });

    test('disable should set isDisabled to true', () async {
      final id = await repository.insert(
        name: 'To Disable',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.disable(id);

      final exercise = await repository.getById(id);
      expect(exercise!.isDisabled, isTrue);
    });

    test('enable should set isDisabled to false', () async {
      final id = await repository.insert(
        name: 'To Enable',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.disable(id);
      await repository.enable(id);

      final exercise = await repository.getById(id);
      expect(exercise!.isDisabled, isFalse);
    });

    test('delete should remove exercise', () async {
      final id = await repository.insert(
        name: 'To Delete',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.delete(id);

      final exercise = await repository.getById(id);
      expect(exercise, isNull);
    });
  });

  group('ExerciseRepository - Queries', () {
    test('getAllEnabled should exclude disabled exercises', () async {
      await repository.insert(
        name: 'Enabled 1',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final disabledId = await repository.insert(
        name: 'Disabled',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      await repository.insert(
        name: 'Enabled 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.disable(disabledId);

      final enabled = await repository.getAllEnabled();
      expect(enabled.length, equals(2));
      expect(enabled.any((e) => e.name == 'Disabled'), isFalse);
    });

    test('getAll should include disabled exercises', () async {
      await repository.insert(
        name: 'Enabled',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final disabledId = await repository.insert(
        name: 'Disabled',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.disable(disabledId);

      final all = await repository.getAll();
      expect(all.length, equals(2));
    });

    test('findByName should be case-insensitive', () async {
      await repository.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final found1 = await repository.findByName('Test Exercise');
      final found2 = await repository.findByName('test exercise');
      final found3 = await repository.findByName('TEST EXERCISE');

      expect(found1, isNotNull);
      expect(found2, isNotNull);
      expect(found3, isNotNull);
    });

    test('findByName should return null for non-existent name', () async {
      final found = await repository.findByName('Non Existent');
      expect(found, isNull);
    });

    test('nameExists should return true for existing name', () async {
      await repository.insert(
        name: 'Existing',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final exists = await repository.nameExists('existing');
      expect(exists, isTrue);
    });

    test('nameExists should return false for non-existing name', () async {
      final exists = await repository.nameExists('Non Existing');
      expect(exists, isFalse);
    });

    test('nameExists should exclude specified id', () async {
      final id = await repository.insert(
        name: 'Test',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final existsWithoutExclude = await repository.nameExists('Test');
      final existsWithExclude = await repository.nameExists('Test', excludeId: id);

      expect(existsWithoutExclude, isTrue);
      expect(existsWithExclude, isFalse);
    });

    test('getAllNames should return names of enabled exercises', () async {
      await repository.insert(
        name: 'Exercise A',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final disabledId = await repository.insert(
        name: 'Exercise B',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      await repository.insert(
        name: 'Exercise C',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await repository.disable(disabledId);

      final names = await repository.getAllNames();
      expect(names, containsAll(['Exercise A', 'Exercise C']));
      expect(names, isNot(contains('Exercise B')));
    });

    test('exercises should be ordered by name', () async {
      await repository.insert(
        name: 'Zebra',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      await repository.insert(
        name: 'Apple',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      await repository.insert(
        name: 'Mango',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final all = await repository.getAllEnabled();
      expect(all[0].name, equals('Apple'));
      expect(all[1].name, equals('Mango'));
      expect(all[2].name, equals('Zebra'));
    });
  });

  group('ExerciseRepository - Constraints', () {
    test('insert should throw for empty sets', () async {
      expect(
        () => repository.insert(
          name: 'Empty Sets',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for negative restAfterExercise', () async {
      expect(
        () => repository.insert(
          name: 'Negative Rest',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: createSampleSets(),
          restAfterExercise: -1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for empty name', () async {
      expect(
        () => repository.insert(
          name: '',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: createSampleSets(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for name > 100 chars', () async {
      expect(
        () => repository.insert(
          name: 'a' * 101,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: createSampleSets(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should accept name with exactly 100 chars', () async {
      final id = await repository.insert(
        name: 'a' * 100,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      expect(id, greaterThan(0));
    });

    test('insert should throw for set with invalid rest (negative)', () async {
      expect(
        () => repository.insert(
          name: 'Invalid Set Rest',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: [
            const ExerciseSet(value: 10, weight: 0, rest: 90),
            const ExerciseSet(value: 10, weight: 0, rest: -1),
          ],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for set with invalid rest (zero)', () async {
      expect(
        () => repository.insert(
          name: 'Invalid Set Rest Zero',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: [
            const ExerciseSet(value: 10, weight: 0, rest: 0),
          ],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should fail for duplicate name', () async {
      await repository.insert(
        name: 'Unique Name',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      expect(
        () => repository.insert(
          name: 'Unique Name',
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          sets: createSampleSets(),
        ),
        throwsA(anything), // SqliteException for unique constraint
      );
    });

    test('update should validate sets', () async {
      final id = await repository.insert(
        name: 'Valid Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final exercise = await repository.getById(id);
      final invalidExercise = Exercise(
        id: exercise!.id,
        name: exercise.name,
        type: exercise.type,
        mode: exercise.mode,
        isDefault: exercise.isDefault,
        isDisabled: exercise.isDisabled,
        sets: [], // Invalid: empty sets
        restAfterExercise: exercise.restAfterExercise,
      );

      expect(
        () => repository.update(invalidExercise),
        throwsA(isA<ValidationException>()),
      );
    });

    test('update should validate name', () async {
      final id = await repository.insert(
        name: 'Valid Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final exercise = await repository.getById(id);
      final invalidExercise = Exercise(
        id: exercise!.id,
        name: '', // Invalid: empty name
        type: exercise.type,
        mode: exercise.mode,
        isDefault: exercise.isDefault,
        isDisabled: exercise.isDisabled,
        sets: exercise.sets,
        restAfterExercise: exercise.restAfterExercise,
      );

      expect(
        () => repository.update(invalidExercise),
        throwsA(isA<ValidationException>()),
      );
    });

    test('update should fail when changing to duplicate name', () async {
      await repository.insert(
        name: 'First Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final secondId = await repository.insert(
        name: 'Second Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final second = await repository.getById(secondId);
      final duplicate = Exercise(
        id: second!.id,
        name: 'First Exercise', // Duplicate
        type: second.type,
        mode: second.mode,
        isDefault: second.isDefault,
        isDisabled: second.isDisabled,
        sets: second.sets,
        restAfterExercise: second.restAfterExercise,
      );

      expect(
        () => repository.update(duplicate),
        throwsA(anything), // SqliteException for unique constraint
      );
    });

  });

  group('ExerciseRepository - isDefault behavior', () {
    test('getAllEnabled should include both default and custom', () async {
      await repository.insert(
        name: 'Default Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: true,
      );
      await repository.insert(
        name: 'Custom Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: false,
      );

      final all = await repository.getAllEnabled();
      expect(all.length, equals(2));
      expect(all.any((e) => e.isDefault), isTrue);
      expect(all.any((e) => !e.isDefault), isTrue);
    });

    test('watchCustom should exclude default exercises', () async {
      await repository.insert(
        name: 'Default Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: true,
      );
      await repository.insert(
        name: 'Custom Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: false,
      );

      final custom = await repository.watchCustom().first;
      expect(custom.length, equals(1));
      expect(custom.first.name, equals('Custom Exercise'));
      expect(custom.first.isDefault, isFalse);
    });

    test('disabled default exercise should be excluded from getAllEnabled', () async {
      final defaultId = await repository.insert(
        name: 'Default Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: true,
      );

      await repository.disable(defaultId);

      final all = await repository.getAllEnabled();
      expect(all, isEmpty);
    });
  });

  group('ExerciseRepository - Streams', () {
    test('watchAllEnabled should emit updates', () async {
      final stream = repository.watchAllEnabled();

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await repository.insert(
        name: 'New Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchCustom should exclude default exercises', () async {
      await repository.insert(
        name: 'Default',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: true,
      );
      await repository.insert(
        name: 'Custom',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
        isDefault: false,
      );

      final custom = await repository.watchCustom().first;
      expect(custom.length, equals(1));
      expect(custom.first.name, equals('Custom'));
    });
  });

  group('ExerciseRepository - Type and Mode', () {
    test('should store static type correctly', () async {
      final id = await repository.insert(
        name: 'Static Exercise',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        sets: createSampleSets(value: 30), // 30 seconds
      );

      final exercise = await repository.getById(id);
      expect(exercise!.type, equals(ExerciseType.static));
    });

    test('should store all mode types correctly', () async {
      final repsId = await repository.insert(
        name: 'Reps Mode',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final variableId = await repository.insert(
        name: 'Variable Mode',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.variableSets,
        sets: createSampleSets(),
      );
      final pyramidId = await repository.insert(
        name: 'Pyramid Mode',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.pyramid,
        sets: createSampleSets(),
      );

      final reps = await repository.getById(repsId);
      final variable = await repository.getById(variableId);
      final pyramid = await repository.getById(pyramidId);

      expect(reps!.mode, equals(ExerciseMode.reps));
      expect(variable!.mode, equals(ExerciseMode.variableSets));
      expect(pyramid!.mode, equals(ExerciseMode.pyramid));
    });
  });

  group('ExerciseRepository - Sets JSON', () {
    test('should store and retrieve sets correctly', () async {
      final sets = [
        const ExerciseSet(value: 10, weight: 20, rest: 90),
        const ExerciseSet(value: 12, weight: 25, rest: 60),
        const ExerciseSet(value: 8, weight: 30, rest: null),
      ];

      final id = await repository.insert(
        name: 'Sets Test',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: sets,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.sets.length, equals(3));
      expect(exercise.sets[0].value, equals(10));
      expect(exercise.sets[0].weight, equals(20));
      expect(exercise.sets[0].rest, equals(90));
      expect(exercise.sets[1].value, equals(12));
      expect(exercise.sets[2].rest, isNull);
    });

    test('should store negative weight (for assisted exercises)', () async {
      final sets = [
        const ExerciseSet(value: 10, weight: -20, rest: null), // Assisted pull-up
      ];

      final id = await repository.insert(
        name: 'Assisted Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: sets,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.sets[0].weight, equals(-20));
    });

    test('should store decimal weight', () async {
      final sets = [
        const ExerciseSet(value: 10, weight: 22.5, rest: null),
      ];

      final id = await repository.insert(
        name: 'Decimal Weight',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: sets,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.sets[0].weight, equals(22.5));
    });

    test('should store zero weight', () async {
      final sets = [
        const ExerciseSet(value: 10, weight: 0, rest: null),
      ];

      final id = await repository.insert(
        name: 'Bodyweight',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: sets,
      );

      final exercise = await repository.getById(id);
      expect(exercise!.sets[0].weight, equals(0));
    });
  });

  group('ExerciseRepository - Type/Mode combinations', () {
    test('static type with reps mode (timed hold)', () async {
      final id = await repository.insert(
        name: 'Plank',
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        sets: [const ExerciseSet(value: 60, weight: 0, rest: null)], // 60 seconds
      );

      final exercise = await repository.getById(id);
      expect(exercise!.type, equals(ExerciseType.static));
      expect(exercise.mode, equals(ExerciseMode.reps));
    });

    test('static type with variableSets mode', () async {
      final id = await repository.insert(
        name: 'Variable Plank',
        type: ExerciseType.static,
        mode: ExerciseMode.variableSets,
        sets: [
          const ExerciseSet(value: 30, weight: 0, rest: 60),
          const ExerciseSet(value: 45, weight: 0, rest: 60),
          const ExerciseSet(value: 60, weight: 0, rest: null),
        ],
      );

      final exercise = await repository.getById(id);
      expect(exercise!.type, equals(ExerciseType.static));
      expect(exercise.mode, equals(ExerciseMode.variableSets));
    });

    test('dynamic type with pyramid mode', () async {
      final id = await repository.insert(
        name: 'Pyramid Squats',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.pyramid,
        sets: [
          const ExerciseSet(value: 12, weight: 40, rest: 90),
          const ExerciseSet(value: 10, weight: 50, rest: 90),
          const ExerciseSet(value: 8, weight: 60, rest: 90),
          const ExerciseSet(value: 6, weight: 70, rest: null),
        ],
      );

      final exercise = await repository.getById(id);
      expect(exercise!.type, equals(ExerciseType.dynamic));
      expect(exercise.mode, equals(ExerciseMode.pyramid));
      expect(exercise.sets.length, equals(4));
    });
  });
}
