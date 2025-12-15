import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/models/exercise.dart';

void main() {
  group('Exercise.create()', () {
    test('creates with timestamp-based ID', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
      );

      expect(exercise.id, isNotEmpty);
      // ID should be parseable as a timestamp
      expect(int.tryParse(exercise.id), isNotNull);
      // ID should be a reasonable timestamp (after year 2020)
      final timestamp = int.parse(exercise.id);
      expect(timestamp, greaterThan(1577836800000)); // Jan 1, 2020
    });

    test('dynamic type sets defaultRepsOrDuration to 10', () {
      final exercise = Exercise.create(
        name: 'Dynamic Exercise',
        type: ExerciseType.dynamic,
      );

      expect(exercise.defaultRepsOrDuration, equals(10));
    });

    test('static type sets defaultRepsOrDuration to 30', () {
      final exercise = Exercise.create(
        name: 'Static Exercise',
        type: ExerciseType.static,
      );

      expect(exercise.defaultRepsOrDuration, equals(30));
    });

    test('default sets is 4', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
      );

      expect(exercise.defaultSets, equals(4));
    });

    test('default weight is 0', () {
      final exercise = Exercise.create(
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
      );

      expect(exercise.defaultWeight, equals(0));
    });

    test('can override default values', () {
      final exercise = Exercise.create(
        name: 'Custom Exercise',
        type: ExerciseType.dynamic,
        defaultSets: 5,
        defaultRepsOrDuration: 15,
        defaultWeight: 20.5,
      );

      expect(exercise.defaultSets, equals(5));
      expect(exercise.defaultRepsOrDuration, equals(15));
      expect(exercise.defaultWeight, equals(20.5));
    });
  });

  group('Exercise.isCustom', () {
    test('returns true when ID does NOT start with "default_"', () {
      final customExercise = Exercise(
        id: '1234567890',
        name: 'Custom Exercise',
        type: ExerciseType.dynamic,
      );

      expect(customExercise.isCustom, isTrue);
    });

    test('returns false when ID starts with "default_"', () {
      final defaultExercise = Exercise(
        id: 'default_test',
        name: 'Default Exercise',
        type: ExerciseType.dynamic,
      );

      expect(defaultExercise.isCustom, isFalse);
    });

    test('Exercise.create() creates custom exercises', () {
      final exercise = Exercise.create(
        name: 'Created Exercise',
        type: ExerciseType.dynamic,
      );

      expect(exercise.isCustom, isTrue);
    });
  });

  group('Exercise serialization', () {
    test('toJson contains all fields', () {
      final exercise = Exercise(
        id: 'test_id',
        name: 'Test Exercise',
        type: ExerciseType.dynamic,
        defaultSets: 3,
        defaultRepsOrDuration: 12,
        defaultWeight: 15.5,
      );

      final json = exercise.toJson();

      expect(json['id'], equals('test_id'));
      expect(json['name'], equals('Test Exercise'));
      expect(json['type'], equals('dynamic'));
      expect(json['defaultSets'], equals(3));
      expect(json['defaultRepsOrDuration'], equals(12));
      expect(json['defaultWeight'], equals(15.5));
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Exercise',
        'type': 'static',
        'defaultSets': 5,
        'defaultRepsOrDuration': 45,
        'defaultWeight': 10.0,
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.id, equals('test_id'));
      expect(exercise.name, equals('Test Exercise'));
      expect(exercise.type, equals(ExerciseType.static));
      expect(exercise.defaultSets, equals(5));
      expect(exercise.defaultRepsOrDuration, equals(45));
      expect(exercise.defaultWeight, equals(10.0));
    });

    test('toJson -> fromJson roundtrip preserves all fields', () {
      final original = Exercise(
        id: 'roundtrip_test',
        name: 'Roundtrip Exercise',
        type: ExerciseType.static,
        defaultSets: 6,
        defaultRepsOrDuration: 60,
        defaultWeight: 25.5,
      );

      final json = original.toJson();
      final restored = Exercise.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.defaultSets, equals(original.defaultSets));
      expect(restored.defaultRepsOrDuration, equals(original.defaultRepsOrDuration));
      expect(restored.defaultWeight, equals(original.defaultWeight));
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'id': 'minimal_id',
        'name': 'Minimal Exercise',
        'type': 'dynamic',
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.defaultSets, equals(4));
      expect(exercise.defaultRepsOrDuration, equals(10));
      expect(exercise.defaultWeight, equals(0));
    });
  });

  group('Exercise.copyWith()', () {
    test('preserves ID when copying', () {
      final original = Exercise(
        id: 'original_id',
        name: 'Original',
        type: ExerciseType.dynamic,
      );

      final copy = original.copyWith(name: 'Modified');

      expect(copy.id, equals('original_id'));
    });

    test('updates specified fields', () {
      final original = Exercise(
        id: 'test_id',
        name: 'Original',
        type: ExerciseType.dynamic,
        defaultSets: 4,
        defaultRepsOrDuration: 10,
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
      // Unchanged fields preserved
      expect(copy.type, equals(ExerciseType.dynamic));
      expect(copy.defaultRepsOrDuration, equals(10));
    });
  });

  group('Exercise.repsOrDurationLabel', () {
    test('returns "reps" for dynamic type', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Dynamic',
        type: ExerciseType.dynamic,
      );

      expect(exercise.repsOrDurationLabel, equals('reps'));
    });

    test('returns "seconds" for static type', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Static',
        type: ExerciseType.static,
      );

      expect(exercise.repsOrDurationLabel, equals('seconds'));
    });
  });

  group('Exercise.defaults', () {
    test('contains 10 hardcoded exercises', () {
      expect(Exercise.defaults.length, equals(10));
    });

    test('contains all dynamic exercises', () {
      final dynamicNames = ['Pull Ups', 'Push Ups', 'Dips', 'Leg Press', 'Bench Press', 'Dead Lift'];

      for (final name in dynamicNames) {
        final exercise = Exercise.defaults.firstWhere(
          (e) => e.name == name,
          orElse: () => throw Exception('$name not found'),
        );
        expect(exercise.type, equals(ExerciseType.dynamic),
            reason: '$name should be dynamic');
        expect(exercise.defaultRepsOrDuration, equals(10),
            reason: '$name should have 10 reps');
      }
    });

    test('contains all static exercises', () {
      final staticNames = ['Planche', 'Dead Hang', 'Front Lever', 'Back Lever'];

      for (final name in staticNames) {
        final exercise = Exercise.defaults.firstWhere(
          (e) => e.name == name,
          orElse: () => throw Exception('$name not found'),
        );
        expect(exercise.type, equals(ExerciseType.static),
            reason: '$name should be static');
        expect(exercise.defaultRepsOrDuration, equals(30),
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
}
