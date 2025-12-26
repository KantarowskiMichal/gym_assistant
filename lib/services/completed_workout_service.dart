import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../repositories/completed_workout_repository.dart';
import '../repositories/workout_repository.dart';

/// Data class for a completed workout with details
class CompletedWorkoutWithDetails {
  final CompletedWorkout completedWorkout;
  final Workout? workout; // May be null if workout was deleted
  final List<CompletedExercise> exercises;

  CompletedWorkoutWithDetails({
    required this.completedWorkout,
    this.workout,
    required this.exercises,
  });

  int get id => completedWorkout.id;
  DateTime get date => completedWorkout.date;
  int get workoutId => completedWorkout.workoutId;
  String get workoutName => workout?.name ?? 'Deleted Workout';
  int? get iconCodePoint => workout?.iconCodePoint;
  bool get isOrphaned => workout == null;
}

/// Service for completed workout operations
/// Provides business logic on top of CompletedWorkoutRepository
class CompletedWorkoutService {
  final CompletedWorkoutRepository _completedRepository;
  final WorkoutRepository _workoutRepository;

  CompletedWorkoutService(this._completedRepository, this._workoutRepository);

  /// Factory constructor from database
  factory CompletedWorkoutService.fromDatabase(AppDatabase db) {
    return CompletedWorkoutService(
      CompletedWorkoutRepository(db),
      WorkoutRepository(db),
    );
  }

  // ============ STREAMS (Reactive UI) ============

  /// Watch all completed workouts
  Stream<List<CompletedWorkout>> watchAll() => _completedRepository.watchAll();

  /// Watch completed workouts for a specific date
  Stream<List<CompletedWorkout>> watchForDate(DateTime date) =>
      _completedRepository.watchForDate(date);

  /// Watch exercises for a completed workout
  Stream<List<CompletedExercise>> watchExercisesForCompletedWorkout(
    int completedWorkoutId,
  ) =>
      _completedRepository.watchExercisesForCompletedWorkout(completedWorkoutId);

  /// Watch exercise history for stats
  Stream<List<CompletedExercise>> watchHistoryForExercise(int exerciseId) =>
      _completedRepository.watchHistoryForExercise(exerciseId);

  // ============ ONE-TIME FETCHES ============

  /// Get all completed workouts
  Future<List<CompletedWorkout>> getAll() => _completedRepository.getAll();

  /// Get completed workout by ID
  Future<CompletedWorkout?> getById(int id) => _completedRepository.getById(id);

  /// Get completed workouts for a specific date
  Future<List<CompletedWorkout>> getForDate(DateTime date) =>
      _completedRepository.getForDate(date);

  /// Get completed workouts for a date with full details
  Future<List<CompletedWorkoutWithDetails>> getForDateWithDetails(
    DateTime date,
  ) async {
    final completedWorkouts = await _completedRepository.getForDate(date);
    final result = <CompletedWorkoutWithDetails>[];

    for (final completed in completedWorkouts) {
      final workout = await _workoutRepository.getById(completed.workoutId);
      final exercises = await _completedRepository
          .getExercisesForCompletedWorkout(completed.id);

      result.add(CompletedWorkoutWithDetails(
        completedWorkout: completed,
        workout: workout,
        exercises: exercises,
      ));
    }

    return result;
  }

  /// Check if a workout is completed for a specific date
  Future<bool> isCompleted(int workoutId, DateTime date) =>
      _completedRepository.isCompleted(workoutId, date);

  /// Find completed workout by workout ID and date
  Future<CompletedWorkout?> findByWorkoutAndDate(
    int workoutId,
    DateTime date,
  ) =>
      _completedRepository.findByWorkoutAndDate(workoutId, date);

  /// Get exercises for a completed workout
  Future<List<CompletedExercise>> getExercisesForCompletedWorkout(
    int completedWorkoutId,
  ) =>
      _completedRepository.getExercisesForCompletedWorkout(completedWorkoutId);

  /// Get exercise history for stats
  Future<List<CompletedExercise>> getHistoryForExercise(int exerciseId) =>
      _completedRepository.getHistoryForExercise(exerciseId);

  // ============ COMPLETION OPERATIONS ============

  /// Complete a workout with exercises
  Future<int> completeWorkout({
    required int workoutId,
    required DateTime date,
    required List<CompletedExerciseData> exercises,
  }) async {
    final companions = exercises.map((e) => CompletedExercisesCompanion.insert(
          completedWorkoutId: 0, // Will be set by repository
          exerciseId: e.exerciseId,
          type: e.type,
          mode: e.mode,
          orderIndex: 0, // Will be set by repository
          sets: e.sets,
          restAfterExercise: Value(e.restAfterExercise),
        )).toList();

    return _completedRepository.insertWithExercises(
      workoutId: workoutId,
      date: date,
      exercises: companions,
    );
  }

  /// Complete a workout using the workout's current exercises as template
  Future<int> completeWorkoutFromTemplate({
    required int workoutId,
    required DateTime date,
  }) async {
    final workoutExercises =
        await _workoutRepository.getExercisesForWorkout(workoutId);

    final exerciseData = workoutExercises
        .map((we) => CompletedExerciseData(
              exerciseId: we.exerciseId,
              type: we.type,
              mode: we.mode,
              sets: we.sets,
              restAfterExercise: we.restAfterExercise,
            ))
        .toList();

    return completeWorkout(
      workoutId: workoutId,
      date: date,
      exercises: exerciseData,
    );
  }

  /// Update a completed exercise (e.g., to record actual reps/weight)
  Future<bool> updateCompletedExercise(CompletedExercise exercise) =>
      _completedRepository.updateCompletedExercise(exercise);

  /// Uncomplete a workout (delete the completion record)
  Future<int> uncompleteWorkout(int completedWorkoutId) =>
      _completedRepository.delete(completedWorkoutId);

  // ============ CALENDAR HELPERS ============

  /// Get all dates in a range that have completed workouts
  Future<Set<DateTime>> getCompletedDatesInRange(
    DateTime from,
    DateTime to,
  ) async {
    final allCompleted = await _completedRepository.getAll();
    final dates = <DateTime>{};

    for (final completed in allCompleted) {
      final completedDate = DateTime(
        completed.date.year,
        completed.date.month,
        completed.date.day,
      );
      if (!completedDate.isBefore(from) && !completedDate.isAfter(to)) {
        dates.add(completedDate);
      }
    }

    return dates;
  }

  /// Check if all workouts for a date are completed
  Future<bool> areAllWorkoutsCompletedForDate(
    DateTime date,
    List<int> scheduledWorkoutIds,
  ) async {
    if (scheduledWorkoutIds.isEmpty) return false;

    for (final workoutId in scheduledWorkoutIds) {
      final isCompleted = await _completedRepository.isCompleted(workoutId, date);
      if (!isCompleted) return false;
    }

    return true;
  }
}

/// Data class for creating completed exercises
class CompletedExerciseData {
  final int exerciseId;
  final ExerciseType type;
  final ExerciseMode mode;
  final List<ExerciseSet> sets;
  final int? restAfterExercise;

  CompletedExerciseData({
    required this.exerciseId,
    required this.type,
    required this.mode,
    required this.sets,
    this.restAfterExercise,
  });
}
