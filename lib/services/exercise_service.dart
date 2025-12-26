import '../database/database.dart';
import '../database/converters.dart';
import '../repositories/exercise_repository.dart';

/// Service for exercise-related operations
/// Provides business logic on top of ExerciseRepository
class ExerciseService {
  final ExerciseRepository _repository;

  ExerciseService(this._repository);

  /// Factory constructor from database
  factory ExerciseService.fromDatabase(AppDatabase db) {
    return ExerciseService(ExerciseRepository(db));
  }

  // ============ STREAMS (Reactive UI) ============

  /// Watch all enabled exercises for display in lists
  Stream<List<Exercise>> watchAllEnabled() => _repository.watchAllEnabled();

  /// Watch only custom (user-created) exercises
  Stream<List<Exercise>> watchCustom() => _repository.watchCustom();

  /// Watch all exercises including disabled
  Stream<List<Exercise>> watchAll() => _repository.watchAll();

  // ============ ONE-TIME FETCHES ============

  /// Get all enabled exercises
  Future<List<Exercise>> getAllEnabled() => _repository.getAllEnabled();

  /// Get all exercises
  Future<List<Exercise>> getAll() => _repository.getAll();

  /// Get exercise by ID
  Future<Exercise?> getById(int id) => _repository.getById(id);

  /// Find exercise by name (case-insensitive)
  Future<Exercise?> findByName(String name) => _repository.findByName(name);

  /// Get all exercise names for autocomplete
  Future<List<String>> getAllNames() => _repository.getAllNames();

  // ============ VALIDATION ============

  /// Check if exercise name is available (for create/update forms)
  Future<bool> isNameAvailable(String name, {int? excludeId}) async {
    final exists = await _repository.nameExists(name, excludeId: excludeId);
    return !exists;
  }

  // ============ CRUD OPERATIONS ============

  /// Create a new custom exercise
  Future<int> createExercise({
    required String name,
    required ExerciseType type,
    required ExerciseMode mode,
    required List<ExerciseSet> sets,
    int? restAfterExercise,
  }) {
    return _repository.insert(
      name: name,
      type: type,
      mode: mode,
      sets: sets,
      isDefault: false,
      restAfterExercise: restAfterExercise,
    );
  }

  /// Update an existing exercise
  Future<bool> updateExercise(Exercise exercise) {
    return _repository.update(exercise);
  }

  /// Disable an exercise (soft-delete)
  /// Use this instead of hard delete to preserve referential integrity
  Future<int> disableExercise(int id) => _repository.disable(id);

  /// Re-enable a disabled exercise
  Future<int> enableExercise(int id) => _repository.enable(id);

  /// Hard delete an exercise
  /// Will fail if exercise is referenced by workouts or completed workouts
  Future<int> deleteExercise(int id) => _repository.delete(id);

  // ============ HELPERS ============

  /// Check if exercise can be deleted (not a default exercise)
  bool canDelete(Exercise exercise) => !exercise.isDefault;

  /// Check if exercise can be edited (not a default exercise)
  bool canEdit(Exercise exercise) => !exercise.isDefault;
}
