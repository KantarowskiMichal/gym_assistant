import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/converters.dart';
import '../repositories/workout_repository.dart';
import '../repositories/exercise_repository.dart';

/// Data class combining workout with its exercises for UI display
class WorkoutWithExercises {
  final Workout workout;
  final List<WorkoutExercise> exercises;

  WorkoutWithExercises({
    required this.workout,
    required this.exercises,
  });

  int get exerciseCount => exercises.length;
}

/// Service for workout template operations
/// Provides business logic on top of WorkoutRepository
class WorkoutService {
  final WorkoutRepository _workoutRepository;
  final ExerciseRepository _exerciseRepository;

  WorkoutService(this._workoutRepository, this._exerciseRepository);

  /// Factory constructor from database
  factory WorkoutService.fromDatabase(AppDatabase db) {
    return WorkoutService(
      WorkoutRepository(db),
      ExerciseRepository(db),
    );
  }

  // ============ STREAMS (Reactive UI) ============

  /// Watch all enabled workouts
  Stream<List<Workout>> watchAllEnabled() =>
      _workoutRepository.watchAllEnabled();

  /// Watch all workouts including disabled
  Stream<List<Workout>> watchAll() => _workoutRepository.watchAll();

  /// Watch exercises for a specific workout
  Stream<List<WorkoutExercise>> watchExercisesForWorkout(int workoutId) =>
      _workoutRepository.watchExercisesForWorkout(workoutId);

  // ============ ONE-TIME FETCHES ============

  /// Get all enabled workouts
  Future<List<Workout>> getAllEnabled() => _workoutRepository.getAllEnabled();

  /// Get workout by ID
  Future<Workout?> getById(int id) => _workoutRepository.getById(id);

  /// Find workout by name
  Future<Workout?> findByName(String name) => _workoutRepository.findByName(name);

  /// Get exercises for a workout
  Future<List<WorkoutExercise>> getExercisesForWorkout(int workoutId) =>
      _workoutRepository.getExercisesForWorkout(workoutId);

  /// Get workout with its exercises
  Future<WorkoutWithExercises?> getWorkoutWithExercises(int workoutId) async {
    final workout = await _workoutRepository.getById(workoutId);
    if (workout == null) return null;

    final exercises = await _workoutRepository.getExercisesForWorkout(workoutId);
    return WorkoutWithExercises(workout: workout, exercises: exercises);
  }

  /// Get all workouts with their exercises
  Future<List<WorkoutWithExercises>> getAllWithExercises() async {
    final workouts = await _workoutRepository.getAllEnabled();
    final result = <WorkoutWithExercises>[];

    for (final workout in workouts) {
      final exercises =
          await _workoutRepository.getExercisesForWorkout(workout.id);
      result.add(WorkoutWithExercises(workout: workout, exercises: exercises));
    }

    return result;
  }

  // ============ VALIDATION ============

  /// Check if workout name is available
  Future<bool> isNameAvailable(String name, {int? excludeId}) async {
    final exists = await _workoutRepository.nameExists(name, excludeId: excludeId);
    return !exists;
  }

  // ============ CRUD OPERATIONS ============

  /// Create a new workout with exercises
  Future<int> createWorkout({
    required String name,
    required int iconCodePoint,
    required List<WorkoutExerciseData> exercises,
  }) async {
    final companions = exercises.map((e) => WorkoutExercisesCompanion.insert(
          workoutId: 0, // Will be set by repository
          exerciseId: e.exerciseId,
          type: e.type,
          mode: e.mode,
          orderIndex: 0, // Will be set by repository
          sets: e.sets,
          restAfterExercise: Value(e.restAfterExercise),
        )).toList();

    return _workoutRepository.insertWithExercises(
      name: name,
      iconCodePoint: iconCodePoint,
      exercises: companions,
    );
  }

  /// Update workout metadata (name, icon)
  Future<bool> updateWorkout(Workout workout) =>
      _workoutRepository.update(workout);

  /// Add an exercise to a workout
  Future<int> addExerciseToWorkout({
    required int workoutId,
    required int exerciseId,
    required ExerciseType type,
    required ExerciseMode mode,
    required int orderIndex,
    required List<ExerciseSet> sets,
    int? restAfterExercise,
  }) {
    return _workoutRepository.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseId: exerciseId,
      type: type,
      mode: mode,
      orderIndex: orderIndex,
      sets: sets,
      restAfterExercise: restAfterExercise,
    );
  }

  /// Update a workout exercise
  Future<bool> updateWorkoutExercise(WorkoutExercise exercise) =>
      _workoutRepository.updateWorkoutExercise(exercise);

  /// Remove an exercise from a workout
  Future<int> removeExerciseFromWorkout(int workoutExerciseId) =>
      _workoutRepository.removeExerciseFromWorkout(workoutExerciseId);

  /// Reorder exercises in a workout
  Future<void> reorderExercises(int workoutId, List<int> exerciseIds) =>
      _workoutRepository.reorderExercises(workoutId, exerciseIds);

  /// Replace all exercises in a workout
  Future<void> replaceExercises({
    required int workoutId,
    required List<WorkoutExerciseData> exercises,
  }) async {
    // Clear existing exercises
    await _workoutRepository.clearExercisesFromWorkout(workoutId);

    // Add new exercises
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      await _workoutRepository.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: e.exerciseId,
        type: e.type,
        mode: e.mode,
        orderIndex: i,
        sets: e.sets,
        restAfterExercise: e.restAfterExercise,
      );
    }
  }

  /// Disable a workout (soft-delete)
  Future<int> disableWorkout(int id) => _workoutRepository.disable(id);

  /// Re-enable a disabled workout
  Future<int> enableWorkout(int id) => _workoutRepository.enable(id);

  /// Hard delete a workout
  /// Will fail if workout has schedules or completed workouts
  Future<int> deleteWorkout(int id) => _workoutRepository.delete(id);

  // ============ HELPERS ============

  /// Create WorkoutExerciseData from an Exercise (copies defaults)
  Future<WorkoutExerciseData?> createExerciseDataFromExercise(int exerciseId) async {
    final exercise = await _exerciseRepository.getById(exerciseId);
    if (exercise == null) return null;

    return WorkoutExerciseData(
      exerciseId: exercise.id,
      type: exercise.type,
      mode: exercise.mode,
      sets: exercise.sets,
      restAfterExercise: exercise.restAfterExercise,
    );
  }
}

/// Data class for creating/updating workout exercises
class WorkoutExerciseData {
  final int exerciseId;
  final ExerciseType type;
  final ExerciseMode mode;
  final List<ExerciseSet> sets;
  final int? restAfterExercise;

  WorkoutExerciseData({
    required this.exerciseId,
    required this.type,
    required this.mode,
    required this.sets,
    this.restAfterExercise,
  });
}
