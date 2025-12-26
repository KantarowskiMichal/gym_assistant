import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/database/database.dart';
import 'package:gym_assistant/database/converters.dart';
import 'package:gym_assistant/database/validators.dart';
import 'package:gym_assistant/repositories/exercise_repository.dart';
import 'package:gym_assistant/repositories/workout_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ExerciseRepository exerciseRepo;

  setUp(() async {
    db = createTestDatabase();
    workoutRepo = WorkoutRepository(db);
    exerciseRepo = ExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WorkoutRepository - Workout CRUD', () {
    test('insert should create workout with auto-increment id', () async {
      final id = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );

      expect(id, greaterThan(0));

      final workout = await workoutRepo.getById(id);
      expect(workout, isNotNull);
      expect(workout!.name, equals('Test Workout'));
      expect(workout.iconCodePoint, equals(sampleIconCodePoint));
      expect(workout.isDisabled, isFalse);
    });

    test('getById should return null for non-existent id', () async {
      final workout = await workoutRepo.getById(999);
      expect(workout, isNull);
    });

    test('update should modify workout', () async {
      final id = await workoutRepo.insert(
        name: 'Original Name',
        iconCodePoint: sampleIconCodePoint,
      );

      final original = await workoutRepo.getById(id);
      final updated = original!.copyWith(name: 'Updated Name');

      final success = await workoutRepo.update(updated);
      expect(success, isTrue);

      final fetched = await workoutRepo.getById(id);
      expect(fetched!.name, equals('Updated Name'));
    });

    test('disable should set isDisabled to true', () async {
      final id = await workoutRepo.insert(
        name: 'To Disable',
        iconCodePoint: sampleIconCodePoint,
      );

      await workoutRepo.disable(id);

      final workout = await workoutRepo.getById(id);
      expect(workout!.isDisabled, isTrue);
    });

    test('enable should set isDisabled to false', () async {
      final id = await workoutRepo.insert(
        name: 'To Enable',
        iconCodePoint: sampleIconCodePoint,
      );

      await workoutRepo.disable(id);
      await workoutRepo.enable(id);

      final workout = await workoutRepo.getById(id);
      expect(workout!.isDisabled, isFalse);
    });

    test('delete should remove workout', () async {
      final id = await workoutRepo.insert(
        name: 'To Delete',
        iconCodePoint: sampleIconCodePoint,
      );

      await workoutRepo.delete(id);

      final workout = await workoutRepo.getById(id);
      expect(workout, isNull);
    });
  });

  group('WorkoutRepository - Workout Queries', () {
    test('getAllEnabled should exclude disabled workouts', () async {
      await workoutRepo.insert(
        name: 'Enabled 1',
        iconCodePoint: sampleIconCodePoint,
      );
      final disabledId = await workoutRepo.insert(
        name: 'Disabled',
        iconCodePoint: sampleIconCodePoint,
      );
      await workoutRepo.insert(
        name: 'Enabled 2',
        iconCodePoint: sampleIconCodePoint,
      );

      await workoutRepo.disable(disabledId);

      final enabled = await workoutRepo.getAllEnabled();
      expect(enabled.length, equals(2));
      expect(enabled.any((w) => w.name == 'Disabled'), isFalse);
    });

    test('findByName should be case-insensitive', () async {
      await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );

      final found1 = await workoutRepo.findByName('Test Workout');
      final found2 = await workoutRepo.findByName('test workout');
      final found3 = await workoutRepo.findByName('TEST WORKOUT');

      expect(found1, isNotNull);
      expect(found2, isNotNull);
      expect(found3, isNotNull);
    });

    test('findByName should return null for non-existent name', () async {
      final found = await workoutRepo.findByName('Non Existent');
      expect(found, isNull);
    });

    test('nameExists should return true for existing name', () async {
      await workoutRepo.insert(
        name: 'Existing',
        iconCodePoint: sampleIconCodePoint,
      );

      final exists = await workoutRepo.nameExists('existing');
      expect(exists, isTrue);
    });

    test('nameExists should return false for non-existing name', () async {
      final exists = await workoutRepo.nameExists('Non Existing');
      expect(exists, isFalse);
    });

    test('nameExists should exclude specified id', () async {
      final id = await workoutRepo.insert(
        name: 'Test',
        iconCodePoint: sampleIconCodePoint,
      );

      final existsWithoutExclude = await workoutRepo.nameExists('Test');
      final existsWithExclude = await workoutRepo.nameExists('Test', excludeId: id);

      expect(existsWithoutExclude, isTrue);
      expect(existsWithExclude, isFalse);
    });

    test('workouts should be ordered by name', () async {
      await workoutRepo.insert(name: 'Zebra', iconCodePoint: sampleIconCodePoint);
      await workoutRepo.insert(name: 'Apple', iconCodePoint: sampleIconCodePoint);
      await workoutRepo.insert(name: 'Mango', iconCodePoint: sampleIconCodePoint);

      final all = await workoutRepo.getAllEnabled();
      expect(all[0].name, equals('Apple'));
      expect(all[1].name, equals('Mango'));
      expect(all[2].name, equals('Zebra'));
    });
  });

  group('WorkoutRepository - Workout Constraints', () {
    test('insert should fail for duplicate name', () async {
      await workoutRepo.insert(
        name: 'Unique Name',
        iconCodePoint: sampleIconCodePoint,
      );

      expect(
        () => workoutRepo.insert(
          name: 'Unique Name',
          iconCodePoint: sampleIconCodePoint,
        ),
        throwsA(anything), // SqliteException for unique constraint
      );
    });

    test('insert should throw for empty name', () async {
      expect(
        () => workoutRepo.insert(
          name: '',
          iconCodePoint: sampleIconCodePoint,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for name > 100 chars', () async {
      expect(
        () => workoutRepo.insert(
          name: 'a' * 101,
          iconCodePoint: sampleIconCodePoint,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should accept name with exactly 100 chars', () async {
      final id = await workoutRepo.insert(
        name: 'a' * 100,
        iconCodePoint: sampleIconCodePoint,
      );
      expect(id, greaterThan(0));
    });

    test('update should validate name', () async {
      final id = await workoutRepo.insert(
        name: 'Valid Workout',
        iconCodePoint: sampleIconCodePoint,
      );

      final workout = await workoutRepo.getById(id);
      final invalidWorkout = Workout(
        id: workout!.id,
        name: '', // Invalid: empty name
        iconCodePoint: workout.iconCodePoint,
        isDisabled: workout.isDisabled,
      );

      expect(
        () => workoutRepo.update(invalidWorkout),
        throwsA(isA<ValidationException>()),
      );
    });

    test('update should fail when changing to duplicate name', () async {
      await workoutRepo.insert(
        name: 'First Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final secondId = await workoutRepo.insert(
        name: 'Second Workout',
        iconCodePoint: sampleIconCodePoint,
      );

      final second = await workoutRepo.getById(secondId);
      final duplicate = second!.copyWith(name: 'First Workout');

      expect(
        () => workoutRepo.update(duplicate),
        throwsA(anything), // SqliteException for unique constraint
      );
    });

  });

  group('WorkoutRepository - WorkoutExercise CRUD', () {
    late int workoutId;
    late int exerciseId;

    setUp(() async {
      workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
    });

    test('addExerciseToWorkout should create workout exercise', () async {
      final id = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      expect(id, greaterThan(0));

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.length, equals(1));
      expect(exercises.first.exerciseId, equals(exerciseId));
      expect(exercises.first.workoutId, equals(workoutId));
      expect(exercises.first.orderIndex, equals(0));
    });

    test('addExerciseToWorkout should store restAfterExercise correctly', () async {
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 120,
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.first.restAfterExercise, equals(120));
    });

    test('addExerciseToWorkout should convert 0 restAfterExercise to null', () async {
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 0,
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.first.restAfterExercise, isNull);
    });

    test('updateWorkoutExercise should modify exercise', () async {
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      final updated = exercises.first.copyWith(orderIndex: 5);

      final success = await workoutRepo.updateWorkoutExercise(updated);
      expect(success, isTrue);

      final fetched = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(fetched.first.orderIndex, equals(5));
    });

    test('removeExerciseFromWorkout should delete workout exercise', () async {
      final id = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      await workoutRepo.removeExerciseFromWorkout(id);

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises, isEmpty);
    });

    test('clearExercisesFromWorkout should remove all exercises', () async {
      final exercise2Id = await exerciseRepo.insert(
        name: 'Test Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exercise2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );

      await workoutRepo.clearExercisesFromWorkout(workoutId);

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises, isEmpty);
    });
  });

  group('WorkoutRepository - WorkoutExercise Ordering', () {
    late int workoutId;

    setUp(() async {
      workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
    });

    test('exercises should be ordered by orderIndex', () async {
      final ex1Id = await exerciseRepo.insert(
        name: 'Exercise A',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise B',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex3Id = await exerciseRepo.insert(
        name: 'Exercise C',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      // Insert in reverse order
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 2,
        sets: createSampleSets(),
      );
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex1Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises[0].exerciseId, equals(ex1Id));
      expect(exercises[1].exerciseId, equals(ex2Id));
      expect(exercises[2].exerciseId, equals(ex3Id));
    });

    test('reorderExercises should update orderIndex values', () async {
      final ex1Id = await exerciseRepo.insert(
        name: 'Exercise 1',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex3Id = await exerciseRepo.insert(
        name: 'Exercise 3',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final we1Id = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex1Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      final we2Id = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );
      final we3Id = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 2,
        sets: createSampleSets(),
      );

      // Reorder: 3, 1, 2
      await workoutRepo.reorderExercises(workoutId, [we3Id, we1Id, we2Id]);

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises[0].exerciseId, equals(ex3Id));
      expect(exercises[1].exerciseId, equals(ex1Id));
      expect(exercises[2].exerciseId, equals(ex2Id));
    });
  });

  group('WorkoutRepository - WorkoutExercise Constraints', () {
    late int workoutId;
    late int exerciseId;

    setUp(() async {
      workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
    });

    test('addExerciseToWorkout should throw for empty sets', () async {
      expect(
        () => workoutRepo.addExerciseToWorkout(
          workoutId: workoutId,
          exerciseId: exerciseId,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          orderIndex: 0,
          sets: [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('addExerciseToWorkout should throw for negative orderIndex', () async {
      expect(
        () => workoutRepo.addExerciseToWorkout(
          workoutId: workoutId,
          exerciseId: exerciseId,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          orderIndex: -1,
          sets: createSampleSets(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('addExerciseToWorkout should throw for negative restAfterExercise', () async {
      expect(
        () => workoutRepo.addExerciseToWorkout(
          workoutId: workoutId,
          exerciseId: exerciseId,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          orderIndex: 0,
          sets: createSampleSets(),
          restAfterExercise: -1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('updateWorkoutExercise should validate sets', () async {
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      final invalidExercise = WorkoutExercise(
        id: exercises.first.id,
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: [], // Invalid: empty sets
        restAfterExercise: null,
      );

      expect(
        () => workoutRepo.updateWorkoutExercise(invalidExercise),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('WorkoutRepository - InsertWithExercises', () {
    test('insertWithExercises should create workout and exercises', () async {
      final ex1Id = await exerciseRepo.insert(
        name: 'Exercise 1',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final workoutId = await workoutRepo.insertWithExercises(
        name: 'Full Workout',
        iconCodePoint: sampleIconCodePoint,
        exercises: [
          WorkoutExercisesCompanion.insert(
            workoutId: 0, // Will be replaced
            exerciseId: ex1Id,
            type: ExerciseType.dynamic,
            mode: ExerciseMode.reps,
            orderIndex: 0, // Will be replaced
            sets: createSampleSets(),
          ),
          WorkoutExercisesCompanion.insert(
            workoutId: 0, // Will be replaced
            exerciseId: ex2Id,
            type: ExerciseType.static,
            mode: ExerciseMode.variableSets,
            orderIndex: 0, // Will be replaced
            sets: createSampleSets(value: 30),
          ),
        ],
      );

      final workout = await workoutRepo.getById(workoutId);
      expect(workout, isNotNull);
      expect(workout!.name, equals('Full Workout'));

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.length, equals(2));
      expect(exercises[0].orderIndex, equals(0));
      expect(exercises[1].orderIndex, equals(1));
    });
  });

  group('WorkoutRepository - Streams', () {
    test('watchAllEnabled should emit updates', () async {
      final stream = workoutRepo.watchAllEnabled();

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await workoutRepo.insert(
        name: 'New Workout',
        iconCodePoint: sampleIconCodePoint,
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchExercisesForWorkout should emit updates', () async {
      final workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final stream = workoutRepo.watchExercisesForWorkout(workoutId);

      // Initial state
      expect(await stream.first, isEmpty);

      // After adding exercise
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final afterAdd = await stream.first;
      expect(afterAdd.length, equals(1));
    });
  });

  group('WorkoutRepository - Foreign Key Constraints', () {
    test('deleting workout should restrict if it has workout exercises', () async {
      final workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Deleting workout should fail due to RESTRICT
      expect(
        () => workoutRepo.delete(workoutId),
        throwsA(anything),
      );
    });

    test('deleting workout should succeed after removing all exercises', () async {
      final workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final workoutExerciseId = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Remove workout exercise first
      await workoutRepo.removeExerciseFromWorkout(workoutExerciseId);

      // Now deleting workout should succeed
      await workoutRepo.delete(workoutId);

      // Verify workout is deleted
      final workout = await workoutRepo.getById(workoutId);
      expect(workout, isNull);
    });

    test('deleting exercise should restrict if referenced by workout exercise', () async {
      final workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Deleting exercise should fail due to RESTRICT
      expect(
        () => exerciseRepo.delete(exerciseId),
        throwsA(anything),
      );
    });
  });

  group('WorkoutRepository - Type and Mode', () {
    late int workoutId;
    late int exerciseId;

    setUp(() async {
      workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
    });

    test('should store static type correctly', () async {
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(value: 30),
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.first.type, equals(ExerciseType.static));
    });

    test('should store all mode types correctly', () async {
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );
      final ex3Id = await exerciseRepo.insert(
        name: 'Exercise 3',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.variableSets,
        orderIndex: 1,
        sets: createSampleSets(),
      );
      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.pyramid,
        orderIndex: 2,
        sets: createSampleSets(),
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises[0].mode, equals(ExerciseMode.reps));
      expect(exercises[1].mode, equals(ExerciseMode.variableSets));
      expect(exercises[2].mode, equals(ExerciseMode.pyramid));
    });
  });

  group('WorkoutRepository - Sets JSON', () {
    test('should store and retrieve sets correctly', () async {
      final workoutId = await workoutRepo.insert(
        name: 'Test Workout',
        iconCodePoint: sampleIconCodePoint,
      );
      final exerciseId = await exerciseRepo.insert(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final sets = [
        const ExerciseSet(value: 10, weight: 20, rest: 90),
        const ExerciseSet(value: 12, weight: 25, rest: 60),
        const ExerciseSet(value: 8, weight: 30, rest: null),
      ];

      await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: sets,
      );

      final exercises = await workoutRepo.getExercisesForWorkout(workoutId);
      expect(exercises.first.sets.length, equals(3));
      expect(exercises.first.sets[0].value, equals(10));
      expect(exercises.first.sets[0].weight, equals(20));
      expect(exercises.first.sets[0].rest, equals(90));
      expect(exercises.first.sets[1].value, equals(12));
      expect(exercises.first.sets[2].rest, isNull);
    });
  });
}
