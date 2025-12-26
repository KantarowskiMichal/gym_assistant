import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../database/validators.dart';

// TODO for all repositories probably separat them out per model if makes sens

/// Repository for CompletedWorkout and CompletedExercise CRUD operations with reactive streams
class CompletedWorkoutRepository {
  final AppDatabase _db;

  CompletedWorkoutRepository(this._db);

  // ============ COMPLETED WORKOUT OPERATIONS ============

  /// Watch all completed workouts
  Stream<List<CompletedWorkout>> watchAll() {
    return (_db.select(
      _db.completedWorkouts,
    )..orderBy([(c) => OrderingTerm.desc(c.date)])).watch();
  }

  /// Get all completed workouts (one-time fetch)
  Future<List<CompletedWorkout>> getAll() {
    return (_db.select(
      _db.completedWorkouts,
    )..orderBy([(c) => OrderingTerm.desc(c.date)])).get();
  }

  /// Get completed workout by ID
  Future<CompletedWorkout?> getById(int id) {
    return (_db.select(
      _db.completedWorkouts,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Get completed workouts for a specific date
  Future<List<CompletedWorkout>> getForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));
    return (_db.select(_db.completedWorkouts)..where(
          (c) =>
              c.date.isBiggerOrEqualValue(normalizedDate) &
              c.date.isSmallerThanValue(nextDay),
        ))
        .get();
  }

  /// Watch completed workouts for a specific date
  Stream<List<CompletedWorkout>> watchForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));
    return (_db.select(_db.completedWorkouts)..where(
          (c) =>
              c.date.isBiggerOrEqualValue(normalizedDate) &
              c.date.isSmallerThanValue(nextDay),
        ))
        .watch();
  }

  /// Find completed workout by workout ID and date
  Future<CompletedWorkout?> findByWorkoutAndDate(int workoutId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));
    return (_db.select(_db.completedWorkouts)..where(
          (c) =>
              c.workoutId.equals(workoutId) &
              c.date.isBiggerOrEqualValue(normalizedDate) &
              c.date.isSmallerThanValue(nextDay),
        ))
        .getSingleOrNull();
  }

  /// Check if a workout is completed for a specific date
  Future<bool> isCompleted(int workoutId, DateTime date) async {
    final completed = await findByWorkoutAndDate(workoutId, date);
    return completed != null;
  }

  /// Insert a new completed workout
  Future<int> insert({required int workoutId, required DateTime date}) {
    return _db
        .into(_db.completedWorkouts)
        .insert(
          CompletedWorkoutsCompanion.insert(workoutId: workoutId, date: date),
        );
  }

  /// Delete a completed workout (cascades to completed exercises)
  Future<int> delete(int id) {
    return (_db.delete(
      _db.completedWorkouts,
    )..where((c) => c.id.equals(id))).go();
  }

  // ============ COMPLETED EXERCISE OPERATIONS ============

  /// Get exercises for a completed workout (ordered)
  Future<List<CompletedExercise>> getExercisesForCompletedWorkout(
    int completedWorkoutId,
  ) {
    return (_db.select(_db.completedExercises)
          ..where((e) => e.completedWorkoutId.equals(completedWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .get();
  }

  /// Watch exercises for a completed workout (ordered)
  Stream<List<CompletedExercise>> watchExercisesForCompletedWorkout(
    int completedWorkoutId,
  ) {
    return (_db.select(_db.completedExercises)
          ..where((e) => e.completedWorkoutId.equals(completedWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .watch();
  }

  /// Add exercise to completed workout
  /// Throws [ValidationException] if constraints are violated
  Future<int> addCompletedExercise({
    required int completedWorkoutId,
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

    return _db
        .into(_db.completedExercises)
        .insert(
          CompletedExercisesCompanion.insert(
            completedWorkoutId: completedWorkoutId,
            exerciseId: exerciseId,
            type: type,
            mode: mode,
            orderIndex: orderIndex,
            sets: sets,
            restAfterExercise: Value(validatedRest),
          ),
        );
  }

  /// Update a completed exercise
  /// Throws [ValidationException] if constraints are violated
  Future<bool> updateCompletedExercise(CompletedExercise exercise) {
    // Validate constraints
    validateSets(exercise.sets);
    validateOrderIndex(exercise.orderIndex);
    final validatedRest = validateRest(exercise.restAfterExercise);

    final validated = exercise.copyWith(
      restAfterExercise: Value(validatedRest),
    );

    return _db.update(_db.completedExercises).replace(validated);
  }

  /// Insert completed workout with exercises in a transaction
  /// Throws [ValidationException] if constraints are violated
  Future<int> insertWithExercises({
    required int workoutId,
    required DateTime date,
    required List<CompletedExercisesCompanion> exercises,
  }) async {
    return _db.transaction(() async {
      final completedWorkoutId = await insert(workoutId: workoutId, date: date);

      for (var i = 0; i < exercises.length; i++) {
        await _db
            .into(_db.completedExercises)
            .insert(
              exercises[i].copyWith(
                completedWorkoutId: Value(completedWorkoutId),
                orderIndex: Value(i),
              ),
            );
      }

      return completedWorkoutId;
    });
  }

  /// Get exercise history for a specific exercise (for stats/progress tracking)
  Future<List<CompletedExercise>> getHistoryForExercise(int exerciseId) {
    return (_db.select(_db.completedExercises)
          ..where((e) => e.exerciseId.equals(exerciseId))
          ..orderBy([(e) => OrderingTerm.desc(e.completedWorkoutId)]))
        .get();
  }

  /// Watch exercise history for a specific exercise
  Stream<List<CompletedExercise>> watchHistoryForExercise(int exerciseId) {
    return (_db.select(_db.completedExercises)
          ..where((e) => e.exerciseId.equals(exerciseId))
          ..orderBy([(e) => OrderingTerm.desc(e.completedWorkoutId)]))
        .watch();
  }
}
