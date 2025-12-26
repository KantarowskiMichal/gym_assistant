import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../database/validators.dart';

/// Repository for Workout and WorkoutExercise CRUD operations with reactive streams
class WorkoutRepository {
  final AppDatabase _db;

  WorkoutRepository(this._db);

  // ============ WORKOUT OPERATIONS ============

  /// Watch all enabled workouts
  Stream<List<Workout>> watchAllEnabled() {
    return (_db.select(_db.workouts)
          ..where((w) => w.isDisabled.equals(false))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Watch all workouts including disabled
  Stream<List<Workout>> watchAll() {
    return (_db.select(_db.workouts)
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Get all enabled workouts (one-time fetch)
  Future<List<Workout>> getAllEnabled() {
    return (_db.select(_db.workouts)
          ..where((w) => w.isDisabled.equals(false))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  /// Get workout by ID
  Future<Workout?> getById(int id) {
    return (_db.select(_db.workouts)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  /// Find workout by name (case-insensitive)
  Future<Workout?> findByName(String name) {
    return (_db.select(_db.workouts)
          ..where((w) => w.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  /// Check if workout name exists (excluding given ID)
  Future<bool> nameExists(String name, {int? excludeId}) async {
    final query = _db.select(_db.workouts)
      ..where((w) => w.name.lower().equals(name.toLowerCase()));

    if (excludeId != null) {
      query.where((w) => w.id.equals(excludeId).not());
    }

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Insert a new workout
  /// Throws [ValidationException] if constraints are violated
  Future<int> insert({
    required String name,
    required int iconCodePoint,
  }) {
    validateName(name);
    return _db.into(_db.workouts).insert(
          WorkoutsCompanion.insert(
            name: name,
            iconCodePoint: iconCodePoint,
          ),
        );
  }

  /// Update an existing workout
  /// Throws [ValidationException] if constraints are violated
  Future<bool> update(Workout workout) {
    validateName(workout.name);
    return _db.update(_db.workouts).replace(workout);
  }

  /// Soft-delete a workout (set isDisabled = true)
  Future<int> disable(int id) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(id)))
        .write(const WorkoutsCompanion(isDisabled: Value(true)));
  }

  /// Re-enable a disabled workout
  Future<int> enable(int id) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(id)))
        .write(const WorkoutsCompanion(isDisabled: Value(false)));
  }

  /// Hard-delete a workout (only if not referenced)
  Future<int> delete(int id) {
    return (_db.delete(_db.workouts)..where((w) => w.id.equals(id))).go();
  }

  // ============ WORKOUT EXERCISE OPERATIONS ============

  /// Watch exercises for a specific workout (ordered)
  Stream<List<WorkoutExercise>> watchExercisesForWorkout(int workoutId) {
    return (_db.select(_db.workoutExercises)
          ..where((we) => we.workoutId.equals(workoutId))
          ..orderBy([(we) => OrderingTerm.asc(we.orderIndex)]))
        .watch();
  }

  /// Get exercises for a specific workout (one-time fetch)
  Future<List<WorkoutExercise>> getExercisesForWorkout(int workoutId) {
    return (_db.select(_db.workoutExercises)
          ..where((we) => we.workoutId.equals(workoutId))
          ..orderBy([(we) => OrderingTerm.asc(we.orderIndex)]))
        .get();
  }

  /// Add exercise to workout
  /// Throws [ValidationException] if constraints are violated
  Future<int> addExerciseToWorkout({
    required int workoutId,
    required int exerciseId,
    required ExerciseType type,
    required ExerciseMode mode,
    required int orderIndex,
    required List<ExerciseSet> sets,
    int? restAfterExercise,
  }) {
    // Validate constraints
    validateSets(sets);
    validateOrderIndex(orderIndex);
    final validatedRest = validateRest(restAfterExercise);

    return _db.into(_db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            workoutId: workoutId,
            exerciseId: exerciseId,
            type: type,
            mode: mode,
            orderIndex: orderIndex,
            sets: sets,
            restAfterExercise: Value(validatedRest),
          ),
        );
  }

  /// Update a workout exercise
  /// Throws [ValidationException] if constraints are violated
  Future<bool> updateWorkoutExercise(WorkoutExercise workoutExercise) {
    // Validate constraints
    validateSets(workoutExercise.sets);
    validateOrderIndex(workoutExercise.orderIndex);
    final validatedRest = validateRest(workoutExercise.restAfterExercise);

    final validated = workoutExercise.copyWith(
      restAfterExercise: Value(validatedRest),
    );

    return _db.update(_db.workoutExercises).replace(validated);
  }

  /// Remove exercise from workout
  Future<int> removeExerciseFromWorkout(int workoutExerciseId) {
    return (_db.delete(_db.workoutExercises)
          ..where((we) => we.id.equals(workoutExerciseId)))
        .go();
  }

  /// Remove all exercises from workout
  Future<int> clearExercisesFromWorkout(int workoutId) {
    return (_db.delete(_db.workoutExercises)
          ..where((we) => we.workoutId.equals(workoutId)))
        .go();
  }

  /// Reorder exercises in a workout (update all orderIndex values)
  Future<void> reorderExercises(
    int workoutId,
    List<int> workoutExerciseIds,
  ) async {
    await _db.transaction(() async {
      for (var i = 0; i < workoutExerciseIds.length; i++) {
        await (_db.update(_db.workoutExercises)
              ..where((we) => we.id.equals(workoutExerciseIds[i])))
            .write(WorkoutExercisesCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Insert workout with exercises in a transaction
  /// Throws [ValidationException] if constraints are violated
  Future<int> insertWithExercises({
    required String name,
    required int iconCodePoint,
    required List<WorkoutExercisesCompanion> exercises,
  }) async {
    return _db.transaction(() async {
      final workoutId = await insert(name: name, iconCodePoint: iconCodePoint);

      for (var i = 0; i < exercises.length; i++) {
        await _db.into(_db.workoutExercises).insert(
              exercises[i].copyWith(
                workoutId: Value(workoutId),
                orderIndex: Value(i),
              ),
            );
      }

      return workoutId;
    });
  }
}
