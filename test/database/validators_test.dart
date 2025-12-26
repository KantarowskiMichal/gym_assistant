import 'package:flutter_test/flutter_test.dart';
import 'package:gym_assistant/database/converters.dart';
import 'package:gym_assistant/database/validators.dart';

void main() {
  group('validateName', () {
    test('should pass for valid names (1-100 chars)', () {
      expect(() => validateName('A'), returnsNormally);
      expect(() => validateName('Valid Name'), returnsNormally);
      expect(() => validateName('a' * 100), returnsNormally);
    });

    test('should throw ValidationException for empty name', () {
      expect(
        () => validateName(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for name > 100 chars', () {
      expect(
        () => validateName('a' * 101),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should include field name in exception', () {
      try {
        validateName('');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ValidationException>());
        expect((e as ValidationException).field, equals('name'));
      }
    });

    test('should allow custom field name', () {
      try {
        validateName('', field: 'customField');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ValidationException>());
        expect((e as ValidationException).field, equals('customField'));
      }
    });
  });

  group('validateSets', () {
    test('should pass with one or more sets', () {
      expect(
        () => validateSets([const ExerciseSet(value: 10, weight: 0)]),
        returnsNormally,
      );
      expect(
        () => validateSets([
          const ExerciseSet(value: 10, weight: 0),
          const ExerciseSet(value: 10, weight: 0),
        ]),
        returnsNormally,
      );
    });

    test('should throw ValidationException with empty sets', () {
      expect(
        () => validateSets([]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should include field name in exception', () {
      try {
        validateSets([]);
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ValidationException>());
        expect((e as ValidationException).field, equals('sets'));
      }
    });

    test('should pass with valid rest values in sets', () {
      expect(
        () => validateSets([
          const ExerciseSet(value: 10, weight: 0, rest: null),
          const ExerciseSet(value: 10, weight: 0, rest: 1),
          const ExerciseSet(value: 10, weight: 0, rest: 90),
        ]),
        returnsNormally,
      );
    });

    test('should throw for negative rest in any set', () {
      expect(
        () => validateSets([
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: -1),
        ]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw for zero rest in any set', () {
      // Note: 0 should be stored as null, so if 0 is passed it's invalid
      expect(
        () => validateSets([
          const ExerciseSet(value: 10, weight: 0, rest: 0),
        ]),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should include set index in field name for rest error', () {
      try {
        validateSets([
          const ExerciseSet(value: 10, weight: 0, rest: 90),
          const ExerciseSet(value: 10, weight: 0, rest: -5),
        ]);
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ValidationException>());
        expect((e as ValidationException).field, equals('sets[1].rest'));
      }
    });
  });

  group('validateRest', () {
    test('should return null for null input', () {
      expect(validateRest(null), isNull);
    });

    test('should return null for 0 input (0 stored as null)', () {
      expect(validateRest(0), isNull);
    });

    test('should pass through valid rest values (>= 1)', () {
      expect(validateRest(1), equals(1));
      expect(validateRest(90), equals(90));
      expect(validateRest(300), equals(300));
    });

    test('should throw ValidationException for negative values', () {
      expect(
        () => validateRest(-1),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateRest(-100),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('validateOrderIndex', () {
    test('should pass for 0 and positive values', () {
      expect(() => validateOrderIndex(0), returnsNormally);
      expect(() => validateOrderIndex(1), returnsNormally);
      expect(() => validateOrderIndex(100), returnsNormally);
    });

    test('should throw ValidationException for negative values', () {
      expect(
        () => validateOrderIndex(-1),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => validateOrderIndex(-100),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('validateOffsetDays', () {
    test('should pass for oneOff recurrence with any offsetDays', () {
      expect(
        () => validateOffsetDays(RecurrenceType.oneOff, null),
        returnsNormally,
      );
      expect(
        () => validateOffsetDays(RecurrenceType.oneOff, 0),
        returnsNormally,
      );
      expect(
        () => validateOffsetDays(RecurrenceType.oneOff, 5),
        returnsNormally,
      );
    });

    test('should pass for weekly recurrence with any offsetDays', () {
      expect(
        () => validateOffsetDays(RecurrenceType.weekly, null),
        returnsNormally,
      );
      expect(
        () => validateOffsetDays(RecurrenceType.weekly, 0),
        returnsNormally,
      );
    });

    test('should pass for offset recurrence with valid offsetDays (>= 1)', () {
      expect(
        () => validateOffsetDays(RecurrenceType.offset, 1),
        returnsNormally,
      );
      expect(
        () => validateOffsetDays(RecurrenceType.offset, 7),
        returnsNormally,
      );
      expect(
        () => validateOffsetDays(RecurrenceType.offset, 30),
        returnsNormally,
      );
    });

    test('should throw for offset recurrence with null offsetDays', () {
      expect(
        () => validateOffsetDays(RecurrenceType.offset, null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw for offset recurrence with 0 offsetDays', () {
      expect(
        () => validateOffsetDays(RecurrenceType.offset, 0),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw for offset recurrence with negative offsetDays', () {
      expect(
        () => validateOffsetDays(RecurrenceType.offset, -1),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('validateXorConstraint', () {
    test('should pass when only exerciseId is set', () {
      expect(
        () => validateXorConstraint(exerciseId: 1, workoutExerciseId: null),
        returnsNormally,
      );
    });

    test('should pass when only workoutExerciseId is set', () {
      expect(
        () => validateXorConstraint(exerciseId: null, workoutExerciseId: 1),
        returnsNormally,
      );
    });

    test('should throw when both are null', () {
      expect(
        () => validateXorConstraint(exerciseId: null, workoutExerciseId: null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw when both are set', () {
      expect(
        () => validateXorConstraint(exerciseId: 1, workoutExerciseId: 2),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should include field name in exception', () {
      try {
        validateXorConstraint(exerciseId: null, workoutExerciseId: null);
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ValidationException>());
        expect(
          (e as ValidationException).field,
          equals('exerciseId/workoutExerciseId'),
        );
      }
    });
  });

  group('ValidationException', () {
    test('should have correct toString format', () {
      final exception = ValidationException('testField', 'test message');
      expect(
        exception.toString(),
        equals('ValidationException: testField - test message'),
      );
    });
  });
}
