import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../database/helpers.dart' show scheduleOccursOn;
import '../database/validators.dart';

/// Repository for Schedule and Override CRUD operations with reactive streams
class ScheduleRepository {
  final AppDatabase _db;

  ScheduleRepository(this._db);

  // ============ SCHEDULE OPERATIONS ============

  /// Watch all schedules
  Stream<List<Schedule>> watchAll() {
    return _db.select(_db.schedules).watch();
  }

  /// Get all schedules (one-time fetch)
  Future<List<Schedule>> getAll() {
    return _db.select(_db.schedules).get();
  }

  /// Get schedule by ID
  Future<Schedule?> getById(int id) {
    return (_db.select(_db.schedules)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get schedules for a specific workout
  Future<List<Schedule>> getForWorkout(int workoutId) {
    return (_db.select(_db.schedules)
          ..where((s) => s.workoutId.equals(workoutId)))
        .get();
  }

  /// Get schedules that occur on a specific date
  Future<List<Schedule>> getForDate(DateTime date) async {
    final allSchedules = await getAll();
    return allSchedules.where((schedule) {
      return scheduleOccursOn(
        startDate: schedule.startDate,
        recurrenceType: schedule.recurrenceType,
        offsetDays: schedule.offsetDays,
        targetDate: date,
      );
    }).toList();
  }

  /// Watch schedules that occur on a specific date
  Stream<List<Schedule>> watchForDate(DateTime date) {
    return watchAll().map((schedules) {
      return schedules.where((schedule) {
        return scheduleOccursOn(
          startDate: schedule.startDate,
          recurrenceType: schedule.recurrenceType,
          offsetDays: schedule.offsetDays,
          targetDate: date,
        );
      }).toList();
    });
  }

  /// Insert a new schedule
  /// Throws [ValidationException] if constraints are violated
  Future<int> insert({
    required int workoutId,
    required DateTime startDate,
    required RecurrenceType recurrenceType,
    int? offsetDays,
  }) {
    // Validate constraints
    validateOffsetDays(recurrenceType, offsetDays);

    return _db.into(_db.schedules).insert(
          SchedulesCompanion.insert(
            workoutId: workoutId,
            startDate: startDate,
            recurrenceType: recurrenceType,
            offsetDays: Value(offsetDays),
          ),
        );
  }

  /// Update an existing schedule
  /// Throws [ValidationException] if constraints are violated
  Future<bool> update(Schedule schedule) {
    // Validate constraints
    validateOffsetDays(schedule.recurrenceType, schedule.offsetDays);

    return _db.update(_db.schedules).replace(schedule);
  }

  /// Delete a schedule (cascades to overrides)
  Future<int> delete(int id) {
    return (_db.delete(_db.schedules)..where((s) => s.id.equals(id))).go();
  }

  // ============ OVERRIDE OPERATIONS ============

  /// Get override for a specific schedule and date
  Future<ScheduleDayWorkoutOverride?> getOverride(
    int scheduleId,
    DateTime date,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return (_db.select(_db.scheduleDayWorkoutOverrides)
          ..where((o) =>
              o.scheduleId.equals(scheduleId) & o.date.equals(normalizedDate)))
        .getSingleOrNull();
  }

  /// Watch override for a specific schedule and date
  Stream<ScheduleDayWorkoutOverride?> watchOverride(
    int scheduleId,
    DateTime date,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return (_db.select(_db.scheduleDayWorkoutOverrides)
          ..where((o) =>
              o.scheduleId.equals(scheduleId) & o.date.equals(normalizedDate)))
        .watchSingleOrNull();
  }

  /// Insert a new override
  Future<int> insertOverride({
    required int scheduleId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _db.into(_db.scheduleDayWorkoutOverrides).insert(
          ScheduleDayWorkoutOverridesCompanion.insert(
            scheduleId: scheduleId,
            date: normalizedDate,
          ),
        );
  }

  /// Delete an override (cascades to override exercises)
  Future<int> deleteOverride(int overrideId) {
    return (_db.delete(_db.scheduleDayWorkoutOverrides)
          ..where((o) => o.id.equals(overrideId)))
        .go();
  }

  // ============ OVERRIDE EXERCISE OPERATIONS ============

  /// Get exercises for an override (ordered)
  Future<List<ScheduleDayWorkoutOverrideExercise>> getOverrideExercises(
    int overrideId,
  ) {
    return (_db.select(_db.scheduleDayWorkoutOverrideExercises)
          ..where((e) => e.scheduleDayWorkoutOverrideId.equals(overrideId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .get();
  }

  /// Watch exercises for an override (ordered)
  Stream<List<ScheduleDayWorkoutOverrideExercise>> watchOverrideExercises(
    int overrideId,
  ) {
    return (_db.select(_db.scheduleDayWorkoutOverrideExercises)
          ..where((e) => e.scheduleDayWorkoutOverrideId.equals(overrideId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .watch();
  }

  /// Add exercise to override (from workout exercise)
  /// Throws [ValidationException] if constraints are violated
  Future<int> addOverrideExerciseFromWorkout({
    required int overrideId,
    required int workoutExerciseId,
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
    // XOR: workoutExerciseId is set, exerciseId is null
    validateXorConstraint(exerciseId: null, workoutExerciseId: workoutExerciseId);

    return _db.into(_db.scheduleDayWorkoutOverrideExercises).insert(
          ScheduleDayWorkoutOverrideExercisesCompanion.insert(
            scheduleDayWorkoutOverrideId: overrideId,
            workoutExerciseId: Value(workoutExerciseId),
            type: type,
            mode: mode,
            orderIndex: orderIndex,
            sets: sets,
            restAfterExercise: Value(validatedRest),
          ),
        );
  }

  /// Add exercise to override (new exercise not in original workout)
  /// Throws [ValidationException] if constraints are violated
  Future<int> addOverrideExerciseNew({
    required int overrideId,
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
    // XOR: exerciseId is set, workoutExerciseId is null
    validateXorConstraint(exerciseId: exerciseId, workoutExerciseId: null);

    return _db.into(_db.scheduleDayWorkoutOverrideExercises).insert(
          ScheduleDayWorkoutOverrideExercisesCompanion.insert(
            scheduleDayWorkoutOverrideId: overrideId,
            exerciseId: Value(exerciseId),
            type: type,
            mode: mode,
            orderIndex: orderIndex,
            sets: sets,
            restAfterExercise: Value(validatedRest),
          ),
        );
  }

  /// Update an override exercise
  /// Throws [ValidationException] if constraints are violated
  Future<bool> updateOverrideExercise(
    ScheduleDayWorkoutOverrideExercise exercise,
  ) {
    // Validate constraints
    validateSets(exercise.sets);
    validateOrderIndex(exercise.orderIndex);
    final validatedRest = validateRest(exercise.restAfterExercise);
    validateXorConstraint(
      exerciseId: exercise.exerciseId,
      workoutExerciseId: exercise.workoutExerciseId,
    );

    final validated = exercise.copyWith(
      restAfterExercise: Value(validatedRest),
    );

    return _db.update(_db.scheduleDayWorkoutOverrideExercises).replace(validated);
  }

  /// Remove exercise from override
  Future<int> removeOverrideExercise(int overrideExerciseId) {
    return (_db.delete(_db.scheduleDayWorkoutOverrideExercises)
          ..where((e) => e.id.equals(overrideExerciseId)))
        .go();
  }
}
