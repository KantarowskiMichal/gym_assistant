import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/database/database.dart';
import 'package:gym_assistant/database/converters.dart';
import 'package:gym_assistant/database/validators.dart';
import 'package:gym_assistant/repositories/exercise_repository.dart';
import 'package:gym_assistant/repositories/workout_repository.dart';
import 'package:gym_assistant/repositories/completed_workout_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late CompletedWorkoutRepository completedWorkoutRepo;
  late WorkoutRepository workoutRepo;
  late ExerciseRepository exerciseRepo;
  late int workoutId;
  late int exerciseId;

  setUp(() async {
    db = createTestDatabase();
    completedWorkoutRepo = CompletedWorkoutRepository(db);
    workoutRepo = WorkoutRepository(db);
    exerciseRepo = ExerciseRepository(db);

    // Create a workout and exercise for testing
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

  tearDown(() async {
    await db.close();
  });

  group('CompletedWorkoutRepository - CompletedWorkout CRUD', () {
    test('insert should create completed workout with auto-increment id', () async {
      final id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      expect(id, greaterThan(0));

      final completed = await completedWorkoutRepo.getById(id);
      expect(completed, isNotNull);
      expect(completed!.workoutId, equals(workoutId));
    });

    test('getById should return null for non-existent id', () async {
      final completed = await completedWorkoutRepo.getById(999);
      expect(completed, isNull);
    });

    test('delete should remove completed workout', () async {
      final id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      await completedWorkoutRepo.delete(id);

      final completed = await completedWorkoutRepo.getById(id);
      expect(completed, isNull);
    });
  });

  group('CompletedWorkoutRepository - CompletedWorkout Queries', () {
    test('getAll should return all completed workouts ordered by date desc', () async {
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: yesterday(),
      );
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: tomorrow(),
      );
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final all = await completedWorkoutRepo.getAll();
      expect(all.length, equals(3));
      // Should be ordered by date descending
      expect(all[0].date.isAfter(all[1].date), isTrue);
      expect(all[1].date.isAfter(all[2].date), isTrue);
    });

    test('getForDate should return completed workouts for specific date', () async {
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: tomorrow(),
      );

      final forToday = await completedWorkoutRepo.getForDate(today());
      expect(forToday.length, equals(1));

      final forTomorrow = await completedWorkoutRepo.getForDate(tomorrow());
      expect(forTomorrow.length, equals(1));
    });

    test('getForDate should handle date with time component', () async {
      // Insert with time component
      final dateWithTime = DateTime(
        today().year,
        today().month,
        today().day,
        10,
        30,
      );
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: dateWithTime,
      );

      // Query with different time - should still find it
      final queryDateWithTime = DateTime(
        today().year,
        today().month,
        today().day,
        20,
        45,
      );
      final found = await completedWorkoutRepo.getForDate(queryDateWithTime);
      expect(found.length, equals(1));
    });

    test('findByWorkoutAndDate should return specific completed workout', () async {
      final workout2Id = await workoutRepo.insert(
        name: 'Workout 2',
        iconCodePoint: sampleIconCodePoint,
      );

      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
      await completedWorkoutRepo.insert(
        workoutId: workout2Id,
        date: today(),
      );

      final found = await completedWorkoutRepo.findByWorkoutAndDate(workoutId, today());
      expect(found, isNotNull);
      expect(found!.workoutId, equals(workoutId));

      final notFound = await completedWorkoutRepo.findByWorkoutAndDate(workoutId, tomorrow());
      expect(notFound, isNull);
    });

    test('isCompleted should return correct status', () async {
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final isCompletedToday = await completedWorkoutRepo.isCompleted(workoutId, today());
      expect(isCompletedToday, isTrue);

      final isCompletedTomorrow = await completedWorkoutRepo.isCompleted(workoutId, tomorrow());
      expect(isCompletedTomorrow, isFalse);
    });
  });

  group('CompletedWorkoutRepository - CompletedExercise CRUD', () {
    late int completedWorkoutId;

    setUp(() async {
      completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
    });

    test('addCompletedExercise should create completed exercise', () async {
      final id = await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      expect(id, greaterThan(0));

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.length, equals(1));
      expect(exercises.first.exerciseId, equals(exerciseId));
      expect(exercises.first.completedWorkoutId, equals(completedWorkoutId));
    });

    test('addCompletedExercise should store restAfterExercise correctly', () async {
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 120,
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.first.restAfterExercise, equals(120));
    });

    test('addCompletedExercise should convert 0 restAfterExercise to null', () async {
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 0,
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.first.restAfterExercise, isNull);
    });

    test('updateCompletedExercise should modify exercise', () async {
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      final updated = exercises.first.copyWith(orderIndex: 5);

      final success = await completedWorkoutRepo.updateCompletedExercise(updated);
      expect(success, isTrue);

      final fetched = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(fetched.first.orderIndex, equals(5));
    });

    test('exercises should be ordered by orderIndex', () async {
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

      // Insert in reverse order
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 2,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises[0].exerciseId, equals(exerciseId));
      expect(exercises[1].exerciseId, equals(ex2Id));
      expect(exercises[2].exerciseId, equals(ex3Id));
    });
  });

  group('CompletedWorkoutRepository - CompletedExercise Constraints', () {
    late int completedWorkoutId;

    setUp(() async {
      completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
    });

    test('should throw for empty sets', () async {
      expect(
        () => completedWorkoutRepo.addCompletedExercise(
          completedWorkoutId: completedWorkoutId,
          exerciseId: exerciseId,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          orderIndex: 0,
          sets: [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw for negative orderIndex', () async {
      expect(
        () => completedWorkoutRepo.addCompletedExercise(
          completedWorkoutId: completedWorkoutId,
          exerciseId: exerciseId,
          type: ExerciseType.dynamic,
          mode: ExerciseMode.reps,
          orderIndex: -1,
          sets: createSampleSets(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw for negative restAfterExercise', () async {
      expect(
        () => completedWorkoutRepo.addCompletedExercise(
          completedWorkoutId: completedWorkoutId,
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

    test('updateCompletedExercise should validate sets', () async {
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      final invalid = CompletedExercise(
        id: exercises.first.id,
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: [], // Invalid
        restAfterExercise: null,
      );

      expect(
        () => completedWorkoutRepo.updateCompletedExercise(invalid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('CompletedWorkoutRepository - InsertWithExercises', () {
    test('insertWithExercises should create completed workout and exercises', () async {
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final completedWorkoutId = await completedWorkoutRepo.insertWithExercises(
        workoutId: workoutId,
        date: today(),
        exercises: [
          CompletedExercisesCompanion.insert(
            completedWorkoutId: 0, // Will be replaced
            exerciseId: exerciseId,
            type: ExerciseType.dynamic,
            mode: ExerciseMode.reps,
            orderIndex: 0, // Will be replaced
            sets: createSampleSets(),
          ),
          CompletedExercisesCompanion.insert(
            completedWorkoutId: 0, // Will be replaced
            exerciseId: ex2Id,
            type: ExerciseType.static,
            mode: ExerciseMode.variableSets,
            orderIndex: 0, // Will be replaced
            sets: createSampleSets(value: 30),
          ),
        ],
      );

      final completed = await completedWorkoutRepo.getById(completedWorkoutId);
      expect(completed, isNotNull);

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.length, equals(2));
      expect(exercises[0].orderIndex, equals(0));
      expect(exercises[1].orderIndex, equals(1));
    });
  });

  group('CompletedWorkoutRepository - Exercise History', () {
    test('getHistoryForExercise should return all completed exercises for specific exercise', () async {
      final ex2Id = await exerciseRepo.insert(
        name: 'Exercise 2',
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        sets: createSampleSets(),
      );

      final cw1Id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: yesterday(),
      );
      final cw2Id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: cw1Id,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: cw1Id,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: cw2Id,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final history = await completedWorkoutRepo.getHistoryForExercise(exerciseId);
      expect(history.length, equals(2));

      final ex2History = await completedWorkoutRepo.getHistoryForExercise(ex2Id);
      expect(ex2History.length, equals(1));
    });

    test('getHistoryForExercise should be ordered by completedWorkoutId desc', () async {
      final cw1Id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: yesterday(),
      );
      final cw2Id = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: cw1Id,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: cw2Id,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final history = await completedWorkoutRepo.getHistoryForExercise(exerciseId);
      // cw2Id should be first (most recent)
      expect(history[0].completedWorkoutId, equals(cw2Id));
      expect(history[1].completedWorkoutId, equals(cw1Id));
    });
  });

  group('CompletedWorkoutRepository - Foreign Key Constraints', () {
    test('deleting completed workout should cascade delete completed exercises', () async {
      final completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Verify exercise exists
      var exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.length, equals(1));

      // Delete completed workout
      await completedWorkoutRepo.delete(completedWorkoutId);

      // Exercises should be deleted via CASCADE
      exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises, isEmpty);
    });

    test('deleting workout should restrict if it has completed workouts', () async {
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      // Deleting workout should fail due to RESTRICT
      expect(
        () => workoutRepo.delete(workoutId),
        throwsA(anything),
      );
    });

    test('deleting exercise should restrict if referenced by completed exercise', () async {
      final completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
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

  group('CompletedWorkoutRepository - Streams', () {
    test('watchAll should emit updates', () async {
      final stream = completedWorkoutRepo.watchAll();

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchForDate should emit updates', () async {
      final stream = completedWorkoutRepo.watchForDate(today());

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert on today
      await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchExercisesForCompletedWorkout should emit updates', () async {
      final completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final stream = completedWorkoutRepo.watchExercisesForCompletedWorkout(completedWorkoutId);

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchHistoryForExercise should emit updates', () async {
      final stream = completedWorkoutRepo.watchHistoryForExercise(exerciseId);

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      final completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });
  });

  group('CompletedWorkoutRepository - Type and Mode', () {
    late int completedWorkoutId;

    setUp(() async {
      completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );
    });

    test('should store static type correctly', () async {
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(value: 30),
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
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

      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.variableSets,
        orderIndex: 1,
        sets: createSampleSets(),
      );
      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.pyramid,
        orderIndex: 2,
        sets: createSampleSets(),
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises[0].mode, equals(ExerciseMode.reps));
      expect(exercises[1].mode, equals(ExerciseMode.variableSets));
      expect(exercises[2].mode, equals(ExerciseMode.pyramid));
    });
  });

  group('CompletedWorkoutRepository - Sets JSON', () {
    test('should store and retrieve sets correctly', () async {
      final completedWorkoutId = await completedWorkoutRepo.insert(
        workoutId: workoutId,
        date: today(),
      );

      final sets = [
        const ExerciseSet(value: 10, weight: 20, rest: 90),
        const ExerciseSet(value: 12, weight: 25, rest: 60),
        const ExerciseSet(value: 8, weight: 30, rest: null),
      ];

      await completedWorkoutRepo.addCompletedExercise(
        completedWorkoutId: completedWorkoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: sets,
      );

      final exercises = await completedWorkoutRepo.getExercisesForCompletedWorkout(completedWorkoutId);
      expect(exercises.first.sets.length, equals(3));
      expect(exercises.first.sets[0].value, equals(10));
      expect(exercises.first.sets[0].weight, equals(20));
      expect(exercises.first.sets[0].rest, equals(90));
      expect(exercises.first.sets[1].value, equals(12));
      expect(exercises.first.sets[2].rest, isNull);
    });
  });
}
