import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/models/exercise.dart';

void main() {
  group('Exercise.create()', () {
    test('creates with timestamp-based ID', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        mode: ExerciseMode.reps,
      );

      expect(exercise.id, isNotEmpty);
      expect(int.tryParse(exercise.id), isNotNull);
      final timestamp = int.parse(exercise.id);
      expect(timestamp, greaterThan(1577836800000)); // Jan 1, 2020
    });

    test('reps mode sets defaultReps to 10', () {
      final exercise = Exercise.create(
        name: 'Reps Exercise',
        mode: ExerciseMode.reps,
      );

      expect(exercise.defaultReps, equals(10));
    });

    test('static mode sets defaultSeconds to 30', () {
      final exercise = Exercise.create(
        name: 'Static Exercise',
        mode: ExerciseMode.static,
      );

      expect(exercise.defaultSeconds, equals(30));
    });

    test('pyramid mode sets defaultPyramidTop to 10', () {
      final exercise = Exercise.create(
        name: 'Pyramid Exercise',
        mode: ExerciseMode.pyramid,
      );

      expect(exercise.defaultPyramidTop, equals(10));
    });

    test('default sets is 4', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        mode: ExerciseMode.reps,
      );

      expect(exercise.defaultSets, equals(4));
    });

    test('default weight is 0', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        mode: ExerciseMode.reps,
      );

      expect(exercise.defaultWeight, equals(0));
    });

    test('can override default values', () {
      final exercise = Exercise.create(
        name: 'Custom Exercise',
        mode: ExerciseMode.reps,
        defaultSets: 5,
        defaultReps: 15,
        defaultWeight: 20.5,
      );

      expect(exercise.defaultSets, equals(5));
      expect(exercise.defaultReps, equals(15));
      expect(exercise.defaultWeight, equals(20.5));
    });
  });

  group('Exercise.isCustom', () {
    test('returns true when ID does NOT start with "default_"', () {
      final customExercise = Exercise(
        id: '1234567890',
        name: 'Custom Exercise',
        mode: ExerciseMode.reps,
      );

      expect(customExercise.isCustom, isTrue);
    });

    test('returns false when ID starts with "default_"', () {
      final defaultExercise = Exercise(
        id: 'default_test',
        name: 'Default Exercise',
        mode: ExerciseMode.reps,
      );

      expect(defaultExercise.isCustom, isFalse);
    });

    test('Exercise.create() creates custom exercises', () {
      final exercise = Exercise.create(
        name: 'Created Exercise',
        mode: ExerciseMode.reps,
      );

      expect(exercise.isCustom, isTrue);
    });
  });

  group('Exercise serialization', () {
    test('toJson contains all fields', () {
      final exercise = Exercise(
        id: 'test_id',
        name: 'Test Exercise',
        mode: ExerciseMode.reps,
        defaultSets: 3,
        defaultReps: 12,
        defaultWeight: 15.5,
      );

      final json = exercise.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['name'], equals('Test Exercise'));
      expect(json['mode'], equals('reps'));
      expect(json['defaultSets'], equals(3));
      expect(json['defaultReps'], equals(12));
      expect(json['defaultWeight'], equals(15.5));
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Exercise',
        'mode': 'static',
        'defaultSets': 5,
        'defaultSeconds': 45,
        'defaultWeight': 10.0,
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.id, equals('test_id'));
      expect(exercise.name, equals('Test Exercise'));
      expect(exercise.mode, equals(ExerciseMode.static));
      expect(exercise.defaultSets, equals(5));
      expect(exercise.defaultSeconds, equals(45));
      expect(exercise.defaultWeight, equals(10.0));
    });

    test('toJson -> fromJson roundtrip preserves all fields', () {
      final original = Exercise(
        id: 'roundtrip_test',
        name: 'Roundtrip Exercise',
        mode: ExerciseMode.static,
        defaultSets: 6,
        defaultSeconds: 60,
        defaultWeight: 25.5,
      );

      final json = original.toJson();
      final restored = Exercise.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.mode, equals(original.mode));
      expect(restored.defaultSets, equals(original.defaultSets));
      expect(restored.defaultSeconds, equals(original.defaultSeconds));
      expect(restored.defaultWeight, equals(original.defaultWeight));
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'id': 'minimal_id',
        'name': 'Minimal Exercise',
        'mode': 'reps',
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.defaultSets, equals(4));
      expect(exercise.defaultReps, equals(10));
      expect(exercise.defaultWeight, equals(0));
    });
  });

  group('Exercise.copyWith()', () {
    test('preserves ID when copying', () {
      final original = Exercise(
        id: 'original_id',
        name: 'Original',
        mode: ExerciseMode.reps,
      );

      final copy = original.copyWith(name: 'Modified');

      expect(copy.id, equals('original_id'));
    });

    test('updates specified fields', () {
      final original = Exercise(
        id: 'test_id',
        name: 'Original',
        mode: ExerciseMode.reps,
        defaultSets: 4,
        defaultReps: 10,
        defaultWeight: 0,
      );

      final copy = original.copyWith(
        name: 'Updated',
        defaultSets: 5,
        defaultWeight: 20.0,
      );

      expect(copy.name, equals('Updated'));
      expect(copy.defaultSets, equals(5));
      expect(copy.defaultWeight, equals(20.0));
      expect(copy.mode, equals(ExerciseMode.reps));
      expect(copy.defaultReps, equals(10));
    });
  });

  group('Exercise.modeLabel', () {
    test('returns "Reps" for reps mode', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Reps',
        mode: ExerciseMode.reps,
      );

      expect(exercise.modeLabel, equals('Reps'));
    });

    test('returns "Static" for static mode', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Static',
        mode: ExerciseMode.static,
      );

      expect(exercise.modeLabel, equals('Static'));
    });

    test('returns "Pyramid" for pyramid mode', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Pyramid',
        mode: ExerciseMode.pyramid,
      );

      expect(exercise.modeLabel, equals('Pyramid'));
    });

    test('returns "Variable" for variableSets mode', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Variable',
        mode: ExerciseMode.variableSets,
      );

      expect(exercise.modeLabel, equals('Variable'));
    });
  });

  group('Exercise.defaults', () {
    test('contains 10 hardcoded exercises', () {
      expect(Exercise.defaults.length, equals(10));
    });

    test('contains all reps mode exercises', () {
      final repsNames = ['Pull Ups', 'Push Ups', 'Dips', 'Leg Press', 'Bench Press', 'Dead Lift'];

      for (final name in repsNames) {
        final exercise = Exercise.defaults.firstWhere(
          (e) => e.name == name,
          orElse: () => throw Exception('$name not found'),
        );
        expect(exercise.mode, equals(ExerciseMode.reps),
            reason: '$name should be reps mode');
        expect(exercise.defaultReps, equals(10),
            reason: '$name should have 10 reps');
      }
    });

    test('contains all static mode exercises', () {
      final staticNames = ['Planche', 'Dead Hang', 'Front Lever', 'Back Lever'];

      for (final name in staticNames) {
        final exercise = Exercise.defaults.firstWhere(
          (e) => e.name == name,
          orElse: () => throw Exception('$name not found'),
        );
        expect(exercise.mode, equals(ExerciseMode.static),
            reason: '$name should be static mode');
        expect(exercise.defaultSeconds, equals(30),
            reason: '$name should have 30 seconds');
      }
    });

    test('all defaults have 4 sets', () {
      for (final exercise in Exercise.defaults) {
        expect(exercise.defaultSets, equals(4),
            reason: '${exercise.name} should have 4 sets');
      }
    });

    test('all defaults have IDs starting with "default_"', () {
      for (final exercise in Exercise.defaults) {
        expect(exercise.id.startsWith('default_'), isTrue,
            reason: '${exercise.name} ID should start with "default_"');
        expect(exercise.isCustom, isFalse,
            reason: '${exercise.name} should not be custom');
      }
    });
  });

  group('Exercise.defaultsSummary', () {
    test('reps mode shows sets x reps', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        mode: ExerciseMode.reps,
        defaultSets: 4,
        defaultReps: 10,
      );

      expect(exercise.defaultsSummary, equals('4 × 10 reps'));
    });

    test('static mode shows sets x seconds', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        mode: ExerciseMode.static,
        defaultSets: 3,
        defaultSeconds: 30,
      );

      expect(exercise.defaultsSummary, equals('3 × 30s'));
    });

    test('pyramid mode shows pyramid to top', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        mode: ExerciseMode.pyramid,
        defaultPyramidTop: 10,
      );

      expect(exercise.defaultsSummary, equals('Pyramid to 10'));
    });

    test('variableSets mode shows sets (variable)', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        mode: ExerciseMode.variableSets,
        defaultSets: 4,
      );

      expect(exercise.defaultsSummary, equals('4 sets (variable)'));
    });
  });
}
