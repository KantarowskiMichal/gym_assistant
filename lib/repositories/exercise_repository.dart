import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../database/validators.dart';

/// Repository for Exercise CRUD operations with reactive streams
class ExerciseRepository {
  final AppDatabase _db;

  ExerciseRepository(this._db);

  /// Watch all enabled exercises (for UI lists)
  Stream<List<Exercise>> watchAllEnabled() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isDisabled.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
  }

  /// Watch all exercises including disabled (for admin/settings)
  Stream<List<Exercise>> watchAll() {
    return (_db.select(_db.exercises)
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
  }

  /// Watch only custom (non-default) exercises
  Stream<List<Exercise>> watchCustom() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isDefault.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
  }

  /// Get all enabled exercises (one-time fetch)
  Future<List<Exercise>> getAllEnabled() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isDisabled.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();
  }

  /// Get all exercises (one-time fetch)
  Future<List<Exercise>> getAll() {
    return (_db.select(_db.exercises)
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();
  }

  /// Get exercise by ID
  Future<Exercise?> getById(int id) {
    return (_db.select(_db.exercises)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Find exercise by name (case-insensitive)
  Future<Exercise?> findByName(String name) {
    return (_db.select(_db.exercises)
          ..where((e) => e.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  /// Check if exercise name exists (excluding given ID)
  Future<bool> nameExists(String name, {int? excludeId}) async {
    final query = _db.select(_db.exercises)
      ..where((e) => e.name.lower().equals(name.toLowerCase()));

    if (excludeId != null) {
      query.where((e) => e.id.equals(excludeId).not());
    }

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Get all exercise names for autocomplete
  Future<List<String>> getAllNames() async {
    final exercises = await getAllEnabled();
    return exercises.map((e) => e.name).toList();
  }

  /// Insert a new exercise
  /// Throws [ValidationException] if constraints are violated
  Future<int> insert({
    required String name,
    required ExerciseType type,
    required ExerciseMode mode,
    required List<ExerciseSet> sets,
    bool isDefault = false,
    int? restAfterExercise,
  }) {
    // Validate constraints
    validateName(name);
    validateSets(sets);
    final validatedRest = validateRest(restAfterExercise);

    return _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            name: name,
            type: type,
            mode: mode,
            sets: sets,
            isDefault: Value(isDefault),
            restAfterExercise: Value(validatedRest),
          ),
        );
  }

  /// Update an existing exercise
  /// Throws [ValidationException] if constraints are violated
  Future<bool> update(Exercise exercise) {
    // Validate constraints
    validateName(exercise.name);
    validateSets(exercise.sets);
    final validatedRest = validateRest(exercise.restAfterExercise);

    // Create updated exercise with validated rest
    final validatedExercise = exercise.copyWith(
      restAfterExercise: Value(validatedRest),
    );

    return _db.update(_db.exercises).replace(validatedExercise);
  }

  /// Soft-delete an exercise (set isDisabled = true)
  Future<int> disable(int id) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(const ExercisesCompanion(isDisabled: Value(true)));
  }

  /// Re-enable a disabled exercise
  Future<int> enable(int id) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(const ExercisesCompanion(isDisabled: Value(false)));
  }

  /// Hard-delete an exercise (only if not referenced)
  /// Throws exception if exercise is referenced by other tables
  Future<int> delete(int id) {
    return (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();
  }
}
