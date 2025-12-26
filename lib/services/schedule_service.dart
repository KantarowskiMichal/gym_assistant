import '../database/database.dart';
import '../database/converters.dart';
import '../database/helpers.dart' show getScheduleOccurrencesInRange;
import '../repositories/schedule_repository.dart';
import '../repositories/workout_repository.dart';

/// Data class for a scheduled workout on a specific date
class ScheduledWorkoutForDate {
  final Schedule schedule;
  final Workout workout;
  final DateTime date;
  final ScheduleDayWorkoutOverride? override;

  ScheduledWorkoutForDate({
    required this.schedule,
    required this.workout,
    required this.date,
    this.override,
  });

  int get scheduleId => schedule.id;
  int get workoutId => workout.id;
  String get workoutName => workout.name;
  int get iconCodePoint => workout.iconCodePoint;
  RecurrenceType get recurrenceType => schedule.recurrenceType;
  bool get hasOverride => override != null;
}

/// Service for schedule-related operations
/// Provides business logic on top of ScheduleRepository
class ScheduleService {
  final ScheduleRepository _scheduleRepository;
  final WorkoutRepository _workoutRepository;

  ScheduleService(this._scheduleRepository, this._workoutRepository);

  /// Factory constructor from database
  factory ScheduleService.fromDatabase(AppDatabase db) {
    return ScheduleService(
      ScheduleRepository(db),
      WorkoutRepository(db),
    );
  }

  // ============ STREAMS (Reactive UI) ============

  /// Watch all schedules
  Stream<List<Schedule>> watchAll() => _scheduleRepository.watchAll();

  /// Watch schedules for a specific date
  Stream<List<Schedule>> watchForDate(DateTime date) =>
      _scheduleRepository.watchForDate(date);

  // ============ ONE-TIME FETCHES ============

  /// Get all schedules
  Future<List<Schedule>> getAll() => _scheduleRepository.getAll();

  /// Get schedule by ID
  Future<Schedule?> getById(int id) => _scheduleRepository.getById(id);

  /// Get schedules for a specific workout
  Future<List<Schedule>> getForWorkout(int workoutId) =>
      _scheduleRepository.getForWorkout(workoutId);

  /// Get schedules that occur on a specific date
  Future<List<Schedule>> getForDate(DateTime date) =>
      _scheduleRepository.getForDate(date);

  /// Get scheduled workouts for a specific date with workout details
  Future<List<ScheduledWorkoutForDate>> getScheduledWorkoutsForDate(
    DateTime date,
  ) async {
    final schedules = await _scheduleRepository.getForDate(date);
    final result = <ScheduledWorkoutForDate>[];

    for (final schedule in schedules) {
      final workout = await _workoutRepository.getById(schedule.workoutId);
      if (workout == null || workout.isDisabled) continue;

      final override = await _scheduleRepository.getOverride(schedule.id, date);

      result.add(ScheduledWorkoutForDate(
        schedule: schedule,
        workout: workout,
        date: date,
        override: override,
      ));
    }

    return result;
  }

  /// Get all dates in a range that have scheduled workouts
  Future<Set<DateTime>> getDatesWithWorkoutsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final schedules = await _scheduleRepository.getAll();
    final dates = <DateTime>{};

    for (final schedule in schedules) {
      final workout = await _workoutRepository.getById(schedule.workoutId);
      if (workout == null || workout.isDisabled) continue;

      final occurrences = getScheduleOccurrencesInRange(
        startDate: schedule.startDate,
        recurrenceType: schedule.recurrenceType,
        offsetDays: schedule.offsetDays,
        from: from,
        to: to,
      );
      dates.addAll(occurrences);
    }

    return dates;
  }

  // ============ CRUD OPERATIONS ============

  /// Schedule a workout
  Future<int> scheduleWorkout({
    required int workoutId,
    required DateTime startDate,
    required RecurrenceType recurrenceType,
    int? offsetDays,
  }) {
    return _scheduleRepository.insert(
      workoutId: workoutId,
      startDate: startDate,
      recurrenceType: recurrenceType,
      offsetDays: offsetDays,
    );
  }

  /// Update a schedule
  Future<bool> updateSchedule(Schedule schedule) =>
      _scheduleRepository.update(schedule);

  /// Delete a schedule (and all its overrides)
  Future<int> deleteSchedule(int scheduleId) =>
      _scheduleRepository.delete(scheduleId);

  // ============ OVERRIDE OPERATIONS ============

  /// Get or create an override for a specific schedule and date
  Future<ScheduleDayWorkoutOverride> getOrCreateOverride(
    int scheduleId,
    DateTime date,
  ) async {
    var override = await _scheduleRepository.getOverride(scheduleId, date);
    if (override != null) return override;

    await _scheduleRepository.insertOverride(
      scheduleId: scheduleId,
      date: date,
    );

    return (await _scheduleRepository.getOverride(scheduleId, date))!;
  }

  /// Check if a date has an override
  Future<bool> hasOverride(int scheduleId, DateTime date) async {
    final override = await _scheduleRepository.getOverride(scheduleId, date);
    return override != null;
  }

  /// Delete an override (reverts to base workout exercises)
  Future<int> deleteOverride(int overrideId) =>
      _scheduleRepository.deleteOverride(overrideId);

  // ============ OVERRIDE EXERCISE OPERATIONS ============

  /// Get exercises for an override
  Future<List<ScheduleDayWorkoutOverrideExercise>> getOverrideExercises(
    int overrideId,
  ) =>
      _scheduleRepository.getOverrideExercises(overrideId);

  /// Watch exercises for an override
  Stream<List<ScheduleDayWorkoutOverrideExercise>> watchOverrideExercises(
    int overrideId,
  ) =>
      _scheduleRepository.watchOverrideExercises(overrideId);

  /// Add exercise to override from original workout exercise
  Future<int> addOverrideExerciseFromWorkout({
    required int overrideId,
    required int workoutExerciseId,
    required ExerciseType type,
    required ExerciseMode mode,
    required int orderIndex,
    required List<ExerciseSet> sets,
    int? restAfterExercise,
  }) {
    return _scheduleRepository.addOverrideExerciseFromWorkout(
      overrideId: overrideId,
      workoutExerciseId: workoutExerciseId,
      type: type,
      mode: mode,
      orderIndex: orderIndex,
      sets: sets,
      restAfterExercise: restAfterExercise,
    );
  }

  /// Add new exercise to override (not from original workout)
  Future<int> addOverrideExerciseNew({
    required int overrideId,
    required int exerciseId,
    required ExerciseType type,
    required ExerciseMode mode,
    required int orderIndex,
    required List<ExerciseSet> sets,
    int? restAfterExercise,
  }) {
    return _scheduleRepository.addOverrideExerciseNew(
      overrideId: overrideId,
      exerciseId: exerciseId,
      type: type,
      mode: mode,
      orderIndex: orderIndex,
      sets: sets,
      restAfterExercise: restAfterExercise,
    );
  }

  /// Update an override exercise
  Future<bool> updateOverrideExercise(
    ScheduleDayWorkoutOverrideExercise exercise,
  ) =>
      _scheduleRepository.updateOverrideExercise(exercise);

  /// Remove exercise from override
  Future<int> removeOverrideExercise(int overrideExerciseId) =>
      _scheduleRepository.removeOverrideExercise(overrideExerciseId);

  /// Copy workout exercises to override for customization
  Future<void> copyWorkoutExercisesToOverride({
    required int scheduleId,
    required DateTime date,
  }) async {
    final schedule = await _scheduleRepository.getById(scheduleId);
    if (schedule == null) return;

    final override = await getOrCreateOverride(scheduleId, date);
    final workoutExercises =
        await _workoutRepository.getExercisesForWorkout(schedule.workoutId);

    for (var i = 0; i < workoutExercises.length; i++) {
      final we = workoutExercises[i];
      await addOverrideExerciseFromWorkout(
        overrideId: override.id,
        workoutExerciseId: we.id,
        type: we.type,
        mode: we.mode,
        orderIndex: i,
        sets: we.sets,
        restAfterExercise: we.restAfterExercise,
      );
    }
  }
}
