import 'converters.dart';

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final String message;
  final String field;

  ValidationException(this.field, this.message);

  @override
  String toString() => 'ValidationException: $field - $message';
}

/// Validates name (required, 1-100 chars)
void validateName(String name, {String field = 'name'}) {
  if (name.isEmpty) {
    throw ValidationException(field, 'Name cannot be empty');
  }
  if (name.length > 100) {
    throw ValidationException(field, 'Name cannot exceed 100 characters');
  }
}

/// Validates sets array (must have at least 1 element)
/// Also validates each set's rest value
void validateSets(List<ExerciseSet> sets) {
  if (sets.isEmpty) {
    throw ValidationException('sets', 'Must have at least one set');
  }
  // Validate each set's rest value
  for (var i = 0; i < sets.length; i++) {
    final rest = sets[i].rest;
    if (rest != null && rest < 1) {
      throw ValidationException(
        'sets[$i].rest',
        'Set rest must be >= 1 second when set',
      );
    }
  }
}

/// Validates rest value (must be >= 1 when set, returns null for 0)
int? validateRest(int? rest) {
  if (rest == null || rest == 0) return null;
  if (rest < 1) {
    throw ValidationException('rest', 'Rest must be >= 1 second when set');
  }
  return rest;
}

/// Validates orderIndex (must be >= 0)
void validateOrderIndex(int orderIndex) {
  if (orderIndex < 0) {
    throw ValidationException('orderIndex', 'Order index must be >= 0');
  }
}

/// Validates offsetDays for offset recurrence (must be >= 1)
void validateOffsetDays(RecurrenceType recurrenceType, int? offsetDays) {
  if (recurrenceType == RecurrenceType.offset) {
    if (offsetDays == null || offsetDays < 1) {
      throw ValidationException(
        'offsetDays',
        'Offset days must be >= 1 for offset recurrence',
      );
    }
  }
}

/// Validates XOR constraint (exactly one must be set)
void validateXorConstraint({
  required int? exerciseId,
  required int? workoutExerciseId,
}) {
  final hasExerciseId = exerciseId != null;
  final hasWorkoutExerciseId = workoutExerciseId != null;

  if (hasExerciseId == hasWorkoutExerciseId) {
    throw ValidationException(
      'exerciseId/workoutExerciseId',
      'Exactly one of exerciseId or workoutExerciseId must be set',
    );
  }
}
