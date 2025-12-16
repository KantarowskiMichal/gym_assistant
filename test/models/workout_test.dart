import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/models/workout.dart';
import 'package:gym_assistant/models/exercise.dart';

void main() {
  group('Workout.create()', () {
    test('generates timestamp-based ID', () {
      final workout = Workout.create(
        name: 'Test Workout',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      expect(workout.id, isNotEmpty);
      expect(int.tryParse(workout.id), isNotNull);
      final timestamp = int.parse(workout.id);
      expect(timestamp, greaterThan(1577836800000)); // Jan 1, 2020
    });

    test('uses default icon when none provided', () {
      final workout = Workout.create(
        name: 'Test Workout',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      expect(workout.iconCodePoint, equals(WorkoutIcons.defaultIcon.codePoint));
    });

    test('uses provided icon when specified', () {
      final workout = Workout.create(
        name: 'Test Workout',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
        icon: Icons.directions_run,
      );

      expect(workout.iconCodePoint, equals(Icons.directions_run.codePoint));
    });

    test('creates empty exercises list by default', () {
      final workout = Workout.create(
        name: 'Test Workout',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      expect(workout.exercises, isEmpty);
    });
  });

  group('Workout.occursOn() - OneOff', () {
    late Workout workout;

    setUp(() {
      workout = Workout.create(
        name: 'One-off Workout',
        startDate: DateTime(2025, 1, 15), // Wednesday
        recurrenceType: RecurrenceType.oneOff,
      );
    });

    test('returns true only on exact startDate', () {
      expect(workout.occursOn(DateTime(2025, 1, 15)), isTrue);
    });

    test('returns false day before startDate', () {
      expect(workout.occursOn(DateTime(2025, 1, 14)), isFalse);
    });

    test('returns false day after startDate', () {
      expect(workout.occursOn(DateTime(2025, 1, 16)), isFalse);
    });

    test('returns false one week later', () {
      expect(workout.occursOn(DateTime(2025, 1, 22)), isFalse);
    });

    test('ignores time component', () {
      expect(workout.occursOn(DateTime(2025, 1, 15, 14, 30, 45)), isTrue);
    });
  });

  group('Workout.occursOn() - Weekly', () {
    late Workout workout;

    setUp(() {
      workout = Workout.create(
        name: 'Weekly Workout',
        startDate: DateTime(2025, 1, 15), // Wednesday
        recurrenceType: RecurrenceType.weekly,
      );
    });

    test('returns false before startDate', () {
      expect(workout.occursOn(DateTime(2025, 1, 14)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 8)), isFalse); // Wednesday before
    });

    test('returns true on startDate', () {
      expect(workout.occursOn(DateTime(2025, 1, 15)), isTrue);
    });

    test('returns true on same weekday one week later', () {
      expect(workout.occursOn(DateTime(2025, 1, 22)), isTrue); // Next Wednesday
    });

    test('returns true on same weekday one month later', () {
      expect(workout.occursOn(DateTime(2025, 2, 5)), isTrue);
      expect(workout.occursOn(DateTime(2025, 2, 12)), isTrue);
      expect(workout.occursOn(DateTime(2025, 2, 19)), isTrue);
    });

    test('returns false on different weekday', () {
      expect(workout.occursOn(DateTime(2025, 1, 16)), isFalse); // Thursday
      expect(workout.occursOn(DateTime(2025, 1, 17)), isFalse); // Friday
      expect(workout.occursOn(DateTime(2025, 1, 20)), isFalse); // Monday
    });
  });

  group('Workout.occursOn() - Offset', () {
    test('returns false before startDate', () {
      final workout = Workout.create(
        name: 'Offset Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      expect(workout.occursOn(DateTime(2025, 1, 9)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 1)), isFalse);
    });

    test('returns true on startDate (day 0)', () {
      final workout = Workout.create(
        name: 'Offset Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      expect(workout.occursOn(DateTime(2025, 1, 10)), isTrue);
    });

    test('returns true on startDate + N days', () {
      final workout = Workout.create(
        name: 'Offset Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      expect(workout.occursOn(DateTime(2025, 1, 13)), isTrue); // +3 days
    });

    test('returns true on startDate + 2N days', () {
      final workout = Workout.create(
        name: 'Offset Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      expect(workout.occursOn(DateTime(2025, 1, 16)), isTrue); // +6 days
      expect(workout.occursOn(DateTime(2025, 1, 19)), isTrue); // +9 days
    });

    test('returns false on startDate + 1 (when N > 1)', () {
      final workout = Workout.create(
        name: 'Offset Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      expect(workout.occursOn(DateTime(2025, 1, 11)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 12)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 14)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 15)), isFalse);
    });

    test('returns false if offsetDays is null', () {
      final workout = Workout(
        id: 'test',
        name: 'Offset Workout',
        iconCodePoint: WorkoutIcons.defaultIcon.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: null,
      );

      expect(workout.occursOn(DateTime(2025, 1, 10)), isFalse);
      expect(workout.occursOn(DateTime(2025, 1, 13)), isFalse);
    });

    test('returns false if offsetDays <= 0', () {
      final workoutZero = Workout(
        id: 'test',
        name: 'Offset Workout',
        iconCodePoint: WorkoutIcons.defaultIcon.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 0,
      );

      final workoutNegative = Workout(
        id: 'test',
        name: 'Offset Workout',
        iconCodePoint: WorkoutIcons.defaultIcon.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: -1,
      );

      expect(workoutZero.occursOn(DateTime(2025, 1, 10)), isFalse);
      expect(workoutNegative.occursOn(DateTime(2025, 1, 10)), isFalse);
    });

    test('works with 1 day offset (daily)', () {
      final workout = Workout.create(
        name: 'Daily Workout',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 1,
      );

      expect(workout.occursOn(DateTime(2025, 1, 10)), isTrue);
      expect(workout.occursOn(DateTime(2025, 1, 11)), isTrue);
      expect(workout.occursOn(DateTime(2025, 1, 12)), isTrue);
      expect(workout.occursOn(DateTime(2025, 1, 20)), isTrue);
    });
  });

  group('Workout.getOccurrencesInRange()', () {
    test('returns correct occurrences for oneOff', () {
      final workout = Workout.create(
        name: 'One-off',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final occurrences = workout.getOccurrencesInRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );

      expect(occurrences.length, equals(1));
      expect(occurrences.first, equals(DateTime(2025, 1, 15)));
    });

    test('returns correct occurrences for weekly', () {
      final workout = Workout.create(
        name: 'Weekly',
        startDate: DateTime(2025, 1, 15), // Wednesday
        recurrenceType: RecurrenceType.weekly,
      );

      final occurrences = workout.getOccurrencesInRange(
        DateTime(2025, 1, 15),
        DateTime(2025, 2, 15),
      );

      // Jan 15, 22, 29, Feb 5, 12 = 5 Wednesdays
      expect(occurrences.length, equals(5));
    });

    test('returns correct occurrences for offset', () {
      final workout = Workout.create(
        name: 'Every 3 days',
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      final occurrences = workout.getOccurrencesInRange(
        DateTime(2025, 1, 10),
        DateTime(2025, 1, 20),
      );

      // Jan 10, 13, 16, 19 = 4 occurrences
      expect(occurrences.length, equals(4));
      expect(occurrences, contains(DateTime(2025, 1, 10)));
      expect(occurrences, contains(DateTime(2025, 1, 13)));
      expect(occurrences, contains(DateTime(2025, 1, 16)));
      expect(occurrences, contains(DateTime(2025, 1, 19)));
    });

    test('returns empty list when before startDate', () {
      final workout = Workout.create(
        name: 'Future Workout',
        startDate: DateTime(2025, 2, 1),
        recurrenceType: RecurrenceType.weekly,
      );

      final occurrences = workout.getOccurrencesInRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );

      expect(occurrences, isEmpty);
    });
  });

  group('Workout serialization', () {
    test('toJson contains all fields', () {
      final workout = Workout(
        id: 'test_id',
        name: 'Test Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Push Ups',
            mode: ExerciseMode.reps,
            targetSets: 4,
            targetReps: 10,
          ),
        ],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.weekly,
        offsetDays: null,
      );

      final json = workout.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['name'], equals('Test Workout'));
      expect(json['iconCodePoint'], equals(Icons.fitness_center.codePoint));
      expect(json['exercises'], isA<List>());
      expect((json['exercises'] as List).length, equals(1));
      expect(json['startDate'], equals('2025-01-15T00:00:00.000'));
      expect(json['recurrenceType'], equals('weekly'));
      expect(json['offsetDays'], isNull);
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Workout',
        'iconCodePoint': Icons.directions_run.codePoint,
        'exercises': [
          {
            'exerciseName': 'Plank',
            'mode': 'static',
            'targetSets': 3,
            'targetSeconds': 60,
            'targetWeight': 0,
          },
        ],
        'startDate': '2025-01-15T00:00:00.000',
        'recurrenceType': 'offset',
        'offsetDays': 5,
      };

      final workout = Workout.fromJson(json);

      expect(workout.id, equals('test_id'));
      expect(workout.name, equals('Test Workout'));
      expect(workout.iconCodePoint, equals(Icons.directions_run.codePoint));
      expect(workout.exercises.length, equals(1));
      expect(workout.exercises.first.exerciseName, equals('Plank'));
      expect(workout.startDate, equals(DateTime(2025, 1, 15)));
      expect(workout.recurrenceType, equals(RecurrenceType.offset));
      expect(workout.offsetDays, equals(5));
    });

    test('toJson -> fromJson roundtrip preserves all fields', () {
      final original = Workout(
        id: 'roundtrip_test',
        name: 'Roundtrip Workout',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Exercise 1',
            mode: ExerciseMode.reps,
            targetSets: 4,
            targetReps: 12,
            targetWeight: 20.5,
          ),
          PlannedExercise(
            exerciseName: 'Exercise 2',
            mode: ExerciseMode.static,
            targetSets: 3,
            targetSeconds: 45,
          ),
        ],
        startDate: DateTime(2025, 3, 20),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 7,
      );

      final json = original.toJson();
      final restored = Workout.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.iconCodePoint, equals(original.iconCodePoint));
      expect(restored.exercises.length, equals(original.exercises.length));
      expect(restored.startDate, equals(original.startDate));
      expect(restored.recurrenceType, equals(original.recurrenceType));
      expect(restored.offsetDays, equals(original.offsetDays));
    });
  });

  group('Workout.copyWith()', () {
    test('preserves ID when copying', () {
      final original = Workout.create(
        name: 'Original',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final copy = original.copyWith(name: 'Modified');

      expect(copy.id, equals(original.id));
    });

    test('updates specified fields', () {
      final original = Workout.create(
        name: 'Original',
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final copy = original.copyWith(
        name: 'Updated',
        recurrenceType: RecurrenceType.weekly,
      );

      expect(copy.name, equals('Updated'));
      expect(copy.recurrenceType, equals(RecurrenceType.weekly));
      expect(copy.startDate, equals(original.startDate));
    });
  });

  group('PlannedExercise', () {
    test('reps mode stores target reps', () {
      final exercise = PlannedExercise(
        exerciseName: 'Test Exercise',
        mode: ExerciseMode.reps,
        targetSets: 5,
        targetReps: 15,
        targetWeight: 25.5,
      );

      expect(exercise.exerciseName, equals('Test Exercise'));
      expect(exercise.mode, equals(ExerciseMode.reps));
      expect(exercise.targetSets, equals(5));
      expect(exercise.targetReps, equals(15));
      expect(exercise.targetWeight, equals(25.5));
    });

    test('variableSets mode stores reps per set', () {
      final exercise = PlannedExercise(
        exerciseName: 'Variable Exercise',
        mode: ExerciseMode.variableSets,
        targetSets: 4,
        targetRepsPerSet: [10, 10, 8, 8],
      );

      expect(exercise.mode, equals(ExerciseMode.variableSets));
      expect(exercise.targetRepsPerSet, equals([10, 10, 8, 8]));
    });

    test('pyramid mode stores pyramid top', () {
      final exercise = PlannedExercise(
        exerciseName: 'Pyramid Exercise',
        mode: ExerciseMode.pyramid,
        pyramidTop: 10,
      );

      expect(exercise.mode, equals(ExerciseMode.pyramid));
      expect(exercise.pyramidTop, equals(10));
      expect(exercise.pyramidTotalReps, equals(100)); // 10^2
    });

    test('static mode stores target seconds', () {
      final exercise = PlannedExercise(
        exerciseName: 'Static Exercise',
        mode: ExerciseMode.static,
        targetSets: 3,
        targetSeconds: 45,
      );

      expect(exercise.mode, equals(ExerciseMode.static));
      expect(exercise.targetSeconds, equals(45));
    });

    test('default targetWeight is 0', () {
      final exercise = PlannedExercise(
        exerciseName: 'Test',
        mode: ExerciseMode.reps,
        targetSets: 4,
        targetReps: 10,
      );

      expect(exercise.targetWeight, equals(0));
    });

    test('toJson -> fromJson roundtrip preserves all fields', () {
      final original = PlannedExercise(
        exerciseName: 'Roundtrip Exercise',
        mode: ExerciseMode.variableSets,
        targetSets: 3,
        targetRepsPerSet: [12, 10, 8],
        targetWeight: 10.5,
      );

      final json = original.toJson();
      final restored = PlannedExercise.fromJson(json);

      expect(restored.exerciseName, equals(original.exerciseName));
      expect(restored.mode, equals(original.mode));
      expect(restored.targetSets, equals(original.targetSets));
      expect(restored.targetRepsPerSet, equals(original.targetRepsPerSet));
      expect(restored.targetWeight, equals(original.targetWeight));
    });

    test('modeLabel returns correct label', () {
      expect(PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.reps).modeLabel, equals('Reps'));
      expect(PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.variableSets).modeLabel, equals('Variable'));
      expect(PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.pyramid).modeLabel, equals('Pyramid'));
      expect(PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.static).modeLabel, equals('Static'));
    });

    test('displayString formats correctly for each mode', () {
      expect(
        PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.reps, targetSets: 4, targetReps: 10).displayString,
        equals('4 × 10 reps'),
      );
      expect(
        PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.variableSets, targetSets: 3, targetRepsPerSet: [10, 8, 6]).displayString,
        equals('3 sets (10, 8, 6)'),
      );
      expect(
        PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.pyramid, pyramidTop: 10).displayString,
        equals('Pyramid to 10'),
      );
      expect(
        PlannedExercise(exerciseName: 'Test', mode: ExerciseMode.static, targetSets: 3, targetSeconds: 30).displayString,
        equals('3 × 30s'),
      );
    });

    test('copyWith updates specified fields', () {
      final original = PlannedExercise(
        exerciseName: 'Original',
        mode: ExerciseMode.reps,
        targetSets: 4,
        targetReps: 10,
        targetWeight: 0,
      );

      final copy = original.copyWith(
        targetSets: 5,
        targetWeight: 20.0,
      );

      expect(copy.exerciseName, equals('Original'));
      expect(copy.targetSets, equals(5));
      expect(copy.targetWeight, equals(20.0));
      expect(copy.targetReps, equals(10));
    });
  });

  group('WorkoutIcons', () {
    test('has available icons list', () {
      expect(WorkoutIcons.available, isNotEmpty);
      expect(WorkoutIcons.available.length, greaterThan(10));
    });

    test('has default icon', () {
      expect(WorkoutIcons.defaultIcon, equals(Icons.fitness_center));
    });

    test('fromCodePoint returns icon with correct codePoint', () {
      final icon = WorkoutIcons.fromCodePoint(Icons.pool.codePoint);
      expect(icon.codePoint, equals(Icons.pool.codePoint));
    });

    test('fromCodePoint returns default for null', () {
      final icon = WorkoutIcons.fromCodePoint(null);
      expect(icon.codePoint, equals(WorkoutIcons.defaultIcon.codePoint));
    });
  });
}
