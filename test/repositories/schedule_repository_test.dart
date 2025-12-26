import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/database/database.dart';
import 'package:gym_assistant/database/converters.dart';
import 'package:gym_assistant/database/validators.dart';
import 'package:gym_assistant/repositories/exercise_repository.dart';
import 'package:gym_assistant/repositories/workout_repository.dart';
import 'package:gym_assistant/repositories/schedule_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository scheduleRepo;
  late WorkoutRepository workoutRepo;
  late ExerciseRepository exerciseRepo;
  late int workoutId;
  late int exerciseId;

  setUp(() async {
    db = createTestDatabase();
    scheduleRepo = ScheduleRepository(db);
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

  group('ScheduleRepository - Schedule CRUD', () {
    test('insert should create schedule with auto-increment id', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      expect(id, greaterThan(0));

      final schedule = await scheduleRepo.getById(id);
      expect(schedule, isNotNull);
      expect(schedule!.workoutId, equals(workoutId));
      expect(schedule.recurrenceType, equals(RecurrenceType.oneOff));
      expect(schedule.offsetDays, isNull);
    });

    test('insert should create weekly schedule', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );

      final schedule = await scheduleRepo.getById(id);
      expect(schedule!.recurrenceType, equals(RecurrenceType.weekly));
    });

    test('insert should create offset schedule with offsetDays', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      final schedule = await scheduleRepo.getById(id);
      expect(schedule!.recurrenceType, equals(RecurrenceType.offset));
      expect(schedule.offsetDays, equals(3));
    });

    test('getById should return null for non-existent id', () async {
      final schedule = await scheduleRepo.getById(999);
      expect(schedule, isNull);
    });

    test('update should modify schedule', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      final original = await scheduleRepo.getById(id);
      final updated = original!.copyWith(
        recurrenceType: RecurrenceType.weekly,
      );

      final success = await scheduleRepo.update(updated);
      expect(success, isTrue);

      final fetched = await scheduleRepo.getById(id);
      expect(fetched!.recurrenceType, equals(RecurrenceType.weekly));
    });

    test('delete should remove schedule', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      await scheduleRepo.delete(id);

      final schedule = await scheduleRepo.getById(id);
      expect(schedule, isNull);
    });
  });

  group('ScheduleRepository - Schedule Queries', () {
    test('getAll should return all schedules', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: tomorrow(),
        recurrenceType: RecurrenceType.weekly,
      );

      final all = await scheduleRepo.getAll();
      expect(all.length, equals(2));
    });

    test('getForWorkout should return schedules for specific workout', () async {
      final workout2Id = await workoutRepo.insert(
        name: 'Workout 2',
        iconCodePoint: sampleIconCodePoint,
      );

      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );
      await scheduleRepo.insert(
        workoutId: workout2Id,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: tomorrow(),
        recurrenceType: RecurrenceType.weekly,
      );

      final forWorkout1 = await scheduleRepo.getForWorkout(workoutId);
      expect(forWorkout1.length, equals(2));

      final forWorkout2 = await scheduleRepo.getForWorkout(workout2Id);
      expect(forWorkout2.length, equals(1));
    });
  });

  group('ScheduleRepository - getForDate logic', () {
    test('oneOff should only occur on startDate', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      final onStartDate = await scheduleRepo.getForDate(today());
      expect(onStartDate.length, equals(1));

      final onNextDay = await scheduleRepo.getForDate(tomorrow());
      expect(onNextDay, isEmpty);

      final onPreviousDay = await scheduleRepo.getForDate(yesterday());
      expect(onPreviousDay, isEmpty);
    });

    test('weekly should occur every 7 days from startDate', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );

      // Should occur on start date
      final onStartDate = await scheduleRepo.getForDate(today());
      expect(onStartDate.length, equals(1));

      // Should occur 7 days later
      final oneWeekLater = await scheduleRepo.getForDate(daysFromNow(7));
      expect(oneWeekLater.length, equals(1));

      // Should occur 14 days later
      final twoWeeksLater = await scheduleRepo.getForDate(daysFromNow(14));
      expect(twoWeeksLater.length, equals(1));

      // Should NOT occur 6 days later
      final sixDaysLater = await scheduleRepo.getForDate(daysFromNow(6));
      expect(sixDaysLater, isEmpty);

      // Should NOT occur before start date
      final beforeStart = await scheduleRepo.getForDate(yesterday());
      expect(beforeStart, isEmpty);
    });

    test('offset should occur every N days from startDate', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      // Should occur on start date
      final onStartDate = await scheduleRepo.getForDate(today());
      expect(onStartDate.length, equals(1));

      // Should occur 3 days later
      final threeDaysLater = await scheduleRepo.getForDate(daysFromNow(3));
      expect(threeDaysLater.length, equals(1));

      // Should occur 6 days later
      final sixDaysLater = await scheduleRepo.getForDate(daysFromNow(6));
      expect(sixDaysLater.length, equals(1));

      // Should NOT occur 1 day later
      final oneDayLater = await scheduleRepo.getForDate(daysFromNow(1));
      expect(oneDayLater, isEmpty);

      // Should NOT occur 2 days later
      final twoDaysLater = await scheduleRepo.getForDate(daysFromNow(2));
      expect(twoDaysLater, isEmpty);

      // Should NOT occur before start date
      final beforeStart = await scheduleRepo.getForDate(yesterday());
      expect(beforeStart, isEmpty);
    });

    test('multiple schedules on same date', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );

      final schedules = await scheduleRepo.getForDate(today());
      expect(schedules.length, equals(2));
    });

    test('weekly recurrence across month boundary', () async {
      // Start on last day of current month
      final now = DateTime.now();
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: lastDayOfMonth,
        recurrenceType: RecurrenceType.weekly,
      );

      // Should occur on start date
      final onStart = await scheduleRepo.getForDate(lastDayOfMonth);
      expect(onStart.length, equals(1));

      // Should occur 7 days later (next month)
      final nextWeek = lastDayOfMonth.add(const Duration(days: 7));
      final onNextWeek = await scheduleRepo.getForDate(nextWeek);
      expect(onNextWeek.length, equals(1));
    });

    test('offset recurrence with offset of 1 (daily)', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 1,
      );

      // Should occur every day
      expect((await scheduleRepo.getForDate(today())).length, equals(1));
      expect((await scheduleRepo.getForDate(daysFromNow(1))).length, equals(1));
      expect((await scheduleRepo.getForDate(daysFromNow(2))).length, equals(1));
      expect((await scheduleRepo.getForDate(daysFromNow(100))).length, equals(1));
    });

    test('offset recurrence with large offset', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 30,
      );

      // Should occur on start date
      expect((await scheduleRepo.getForDate(today())).length, equals(1));

      // Should occur 30 days later
      expect((await scheduleRepo.getForDate(daysFromNow(30))).length, equals(1));

      // Should NOT occur at days in between
      expect((await scheduleRepo.getForDate(daysFromNow(15))), isEmpty);
      expect((await scheduleRepo.getForDate(daysFromNow(29))), isEmpty);
    });

    test('schedule with past start date should still work for future occurrences', () async {
      // Start a week ago
      final pastDate = daysFromNow(-7);

      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: pastDate,
        recurrenceType: RecurrenceType.weekly,
      );

      // Should occur today (7 days after start)
      expect((await scheduleRepo.getForDate(today())).length, equals(1));

      // Should occur next week
      expect((await scheduleRepo.getForDate(daysFromNow(7))).length, equals(1));
    });

    test('getForDate should normalize date and ignore time component', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      // Query with time component should still find it
      final dateWithTime = DateTime(
        today().year,
        today().month,
        today().day,
        14,
        30,
        45,
      );
      final found = await scheduleRepo.getForDate(dateWithTime);
      expect(found.length, equals(1));
    });
  });

  group('ScheduleRepository - Schedule Constraints', () {
    test('insert should throw for offset type without offsetDays', () async {
      expect(
        () => scheduleRepo.insert(
          workoutId: workoutId,
          startDate: today(),
          recurrenceType: RecurrenceType.offset,
          offsetDays: null,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should throw for offset type with offsetDays < 1', () async {
      expect(
        () => scheduleRepo.insert(
          workoutId: workoutId,
          startDate: today(),
          recurrenceType: RecurrenceType.offset,
          offsetDays: 0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('insert should allow offsetDays for non-offset types (ignored)', () async {
      // offsetDays is allowed but ignored for non-offset types
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
        offsetDays: 5, // Will be stored but not used
      );

      final schedule = await scheduleRepo.getById(id);
      expect(schedule!.offsetDays, equals(5)); // Stored as-is
    });

    test('update should validate offset constraint', () async {
      final id = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      final schedule = await scheduleRepo.getById(id);
      final invalid = Schedule(
        id: schedule!.id,
        workoutId: schedule.workoutId,
        startDate: schedule.startDate,
        recurrenceType: RecurrenceType.offset,
        offsetDays: null, // Invalid
      );

      expect(
        () => scheduleRepo.update(invalid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleRepository - Override CRUD', () {
    late int scheduleId;

    setUp(() async {
      scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
    });

    test('insertOverride should create override', () async {
      final id = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      expect(id, greaterThan(0));

      final override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNotNull);
      expect(override!.scheduleId, equals(scheduleId));
    });

    test('getOverride should return null for non-existent override', () async {
      final override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNull);
    });

    test('getOverride should normalize date', () async {
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      // Query with time component - should still find it
      final dateWithTime = DateTime(
        today().year,
        today().month,
        today().day,
        15,
        30,
      );
      final override = await scheduleRepo.getOverride(scheduleId, dateWithTime);
      expect(override, isNotNull);
    });

    test('deleteOverride should remove override', () async {
      final id = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      await scheduleRepo.deleteOverride(id);

      final override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNull);
    });

    test('multiple overrides for same schedule on different dates', () async {
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: tomorrow(),
      );
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: daysFromNow(7),
      );

      // Each date should have its own override
      expect(await scheduleRepo.getOverride(scheduleId, today()), isNotNull);
      expect(await scheduleRepo.getOverride(scheduleId, tomorrow()), isNotNull);
      expect(await scheduleRepo.getOverride(scheduleId, daysFromNow(7)), isNotNull);

      // Non-override dates should return null
      expect(await scheduleRepo.getOverride(scheduleId, daysFromNow(2)), isNull);
    });

    test('override with no exercises should be retrievable', () async {
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      final override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNotNull);

      final exercises = await scheduleRepo.getOverrideExercises(override!.id);
      expect(exercises, isEmpty);
    });

    test('override on date not matching schedule occurrence', () async {
      // This tests that override can exist for any date, not just occurrence dates
      // Schedule is weekly starting today, so day 3 is not an occurrence
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: daysFromNow(3),
      );

      final override = await scheduleRepo.getOverride(scheduleId, daysFromNow(3));
      expect(override, isNotNull);
    });
  });

  group('ScheduleRepository - Override Exercise CRUD', () {
    late int scheduleId;
    late int overrideId;
    late int workoutExerciseId;

    setUp(() async {
      scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      workoutExerciseId = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
    });

    test('addOverrideExerciseFromWorkout should create exercise with workoutExerciseId', () async {
      final id = await scheduleRepo.addOverrideExerciseFromWorkout(
        overrideId: overrideId,
        workoutExerciseId: workoutExerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      expect(id, greaterThan(0));

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.length, equals(1));
      expect(exercises.first.workoutExerciseId, equals(workoutExerciseId));
      expect(exercises.first.exerciseId, isNull);
    });

    test('addOverrideExerciseNew should create exercise with exerciseId', () async {
      final id = await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      expect(id, greaterThan(0));

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.length, equals(1));
      expect(exercises.first.exerciseId, equals(exerciseId));
      expect(exercises.first.workoutExerciseId, isNull);
    });

    test('addOverrideExercise should store restAfterExercise correctly', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 120,
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.first.restAfterExercise, equals(120));
    });

    test('addOverrideExercise should convert 0 restAfterExercise to null', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: 0,
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.first.restAfterExercise, isNull);
    });

    test('updateOverrideExercise should modify exercise', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      final updated = exercises.first.copyWith(orderIndex: 5);

      final success = await scheduleRepo.updateOverrideExercise(updated);
      expect(success, isTrue);

      final fetched = await scheduleRepo.getOverrideExercises(overrideId);
      expect(fetched.first.orderIndex, equals(5));
    });

    test('removeOverrideExercise should delete exercise', () async {
      final id = await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      await scheduleRepo.removeOverrideExercise(id);

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises, isEmpty);
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
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 2,
        sets: createSampleSets(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 1,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises[0].exerciseId, equals(exerciseId));
      expect(exercises[1].exerciseId, equals(ex2Id));
      expect(exercises[2].exerciseId, equals(ex3Id));
    });
  });

  group('ScheduleRepository - Override Exercise Constraints', () {
    late int overrideId;
    late int workoutExerciseId;

    setUp(() async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      workoutExerciseId = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
    });

    test('should throw for empty sets', () async {
      expect(
        () => scheduleRepo.addOverrideExerciseNew(
          overrideId: overrideId,
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
        () => scheduleRepo.addOverrideExerciseNew(
          overrideId: overrideId,
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
        () => scheduleRepo.addOverrideExerciseNew(
          overrideId: overrideId,
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

    test('updateOverrideExercise should validate sets', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      final invalid = ScheduleDayWorkoutOverrideExercise(
        id: exercises.first.id,
        scheduleDayWorkoutOverrideId: overrideId,
        exerciseId: exerciseId,
        workoutExerciseId: null,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: [], // Invalid
        restAfterExercise: null,
      );

      expect(
        () => scheduleRepo.updateOverrideExercise(invalid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleRepository - XOR Constraint', () {
    late int overrideId;
    late int workoutExerciseId;

    setUp(() async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      workoutExerciseId = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
    });

    test('addOverrideExerciseFromWorkout sets workoutExerciseId only', () async {
      final id = await scheduleRepo.addOverrideExerciseFromWorkout(
        overrideId: overrideId,
        workoutExerciseId: workoutExerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.first.workoutExerciseId, equals(workoutExerciseId));
      expect(exercises.first.exerciseId, isNull);
    });

    test('addOverrideExerciseNew sets exerciseId only', () async {
      final id = await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.first.exerciseId, equals(exerciseId));
      expect(exercises.first.workoutExerciseId, isNull);
    });

    test('updateOverrideExercise should throw when both are null', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      final invalid = ScheduleDayWorkoutOverrideExercise(
        id: exercises.first.id,
        scheduleDayWorkoutOverrideId: overrideId,
        exerciseId: null, // Both null
        workoutExerciseId: null,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: null,
      );

      expect(
        () => scheduleRepo.updateOverrideExercise(invalid),
        throwsA(isA<ValidationException>()),
      );
    });

    test('updateOverrideExercise should throw when both are set', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      final invalid = ScheduleDayWorkoutOverrideExercise(
        id: exercises.first.id,
        scheduleDayWorkoutOverrideId: overrideId,
        exerciseId: exerciseId, // Both set
        workoutExerciseId: workoutExerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
        restAfterExercise: null,
      );

      expect(
        () => scheduleRepo.updateOverrideExercise(invalid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ScheduleRepository - Foreign Key Constraints', () {
    test('deleting schedule should cascade delete overrides', () async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      // Verify override exists
      var override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNotNull);

      // Delete schedule
      await scheduleRepo.delete(scheduleId);

      // Override should be deleted via CASCADE
      override = await scheduleRepo.getOverride(scheduleId, today());
      expect(override, isNull);
    });

    test('deleting override should cascade delete override exercises', () async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      final overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Verify exercise exists
      var exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises.length, equals(1));

      // Delete override
      await scheduleRepo.deleteOverride(overrideId);

      // Exercises should be deleted via CASCADE
      exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises, isEmpty);
    });

    test('deleting workout should restrict if it has schedules', () async {
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );

      // Deleting workout should fail due to RESTRICT
      expect(
        () => workoutRepo.delete(workoutId),
        throwsA(anything),
      );
    });

    test('deleting exercise should restrict if referenced by override exercise', () async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      final overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
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

    test('deleting workout exercise should restrict if referenced by override exercise', () async {
      final workoutExerciseId = await workoutRepo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      final overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
      await scheduleRepo.addOverrideExerciseFromWorkout(
        overrideId: overrideId,
        workoutExerciseId: workoutExerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );

      // Deleting workout exercise should fail due to RESTRICT
      expect(
        () => workoutRepo.removeExerciseFromWorkout(workoutExerciseId),
        throwsA(anything),
      );
    });
  });

  group('ScheduleRepository - Streams', () {
    test('watchAll should emit updates', () async {
      final stream = scheduleRepo.watchAll();

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchForDate should emit updates', () async {
      final stream = scheduleRepo.watchForDate(today());

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert on today
      await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.oneOff,
      );

      final afterInsert = await stream.first;
      expect(afterInsert.length, equals(1));
    });

    test('watchOverride should emit updates', () async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );

      final stream = scheduleRepo.watchOverride(scheduleId, today());

      // Initial state
      expect(await stream.first, isNull);

      // After insert override
      await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      final afterInsert = await stream.first;
      expect(afterInsert, isNotNull);
    });

    test('watchOverrideExercises should emit updates', () async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      final overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );

      final stream = scheduleRepo.watchOverrideExercises(overrideId);

      // Initial state
      expect(await stream.first, isEmpty);

      // After insert
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
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

  group('ScheduleRepository - Type and Mode', () {
    late int overrideId;

    setUp(() async {
      final scheduleId = await scheduleRepo.insert(
        workoutId: workoutId,
        startDate: today(),
        recurrenceType: RecurrenceType.weekly,
      );
      overrideId = await scheduleRepo.insertOverride(
        scheduleId: scheduleId,
        date: today(),
      );
    });

    test('should store static type correctly', () async {
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.static,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(value: 30),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
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

      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: exerciseId,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.reps,
        orderIndex: 0,
        sets: createSampleSets(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: ex2Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.variableSets,
        orderIndex: 1,
        sets: createSampleSets(),
      );
      await scheduleRepo.addOverrideExerciseNew(
        overrideId: overrideId,
        exerciseId: ex3Id,
        type: ExerciseType.dynamic,
        mode: ExerciseMode.pyramid,
        orderIndex: 2,
        sets: createSampleSets(),
      );

      final exercises = await scheduleRepo.getOverrideExercises(overrideId);
      expect(exercises[0].mode, equals(ExerciseMode.reps));
      expect(exercises[1].mode, equals(ExerciseMode.variableSets));
      expect(exercises[2].mode, equals(ExerciseMode.pyramid));
    });
  });
}
