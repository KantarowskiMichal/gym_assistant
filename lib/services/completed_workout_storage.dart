import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completed_workout.dart';

/// Service to handle saving and loading completed workouts.
/// Completed workouts are archived separately for history tracking.
class CompletedWorkoutStorage {
  static const String _storageKey = 'completed_workouts';

  /// Load all completed workouts
  static Future<List<CompletedWorkout>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => CompletedWorkout.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save all completed workouts
  static Future<void> _save(List<CompletedWorkout> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = workouts.map((w) => w.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Add a new completed workout
  static Future<void> addCompleted(CompletedWorkout workout) async {
    final workouts = await loadAll();
    workouts.add(workout);
    await _save(workouts);
  }

  /// Update an existing completed workout (for editing later)
  static Future<void> updateCompleted(CompletedWorkout workout) async {
    final workouts = await loadAll();
    final index = workouts.indexWhere((w) => w.id == workout.id);
    if (index != -1) {
      workouts[index] = workout;
      await _save(workouts);
    }
  }

  /// Delete a completed workout
  static Future<void> deleteCompleted(String completedWorkoutId) async {
    final workouts = await loadAll();
    workouts.removeWhere((w) => w.id == completedWorkoutId);
    await _save(workouts);
  }

  /// Find a completed workout by scheduled workout ID and date
  static Future<CompletedWorkout?> findCompleted(
    String scheduledWorkoutId,
    DateTime date,
  ) async {
    final workouts = await loadAll();
    final normalizedDate = DateTime(date.year, date.month, date.day);

    try {
      return workouts.firstWhere(
        (w) =>
            w.scheduledWorkoutId == scheduledWorkoutId &&
            w.scheduledDate.year == normalizedDate.year &&
            w.scheduledDate.month == normalizedDate.month &&
            w.scheduledDate.day == normalizedDate.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all completed workouts for a specific date
  static Future<List<CompletedWorkout>> getCompletedForDate(DateTime date) async {
    final workouts = await loadAll();
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return workouts
        .where((w) =>
            w.scheduledDate.year == normalizedDate.year &&
            w.scheduledDate.month == normalizedDate.month &&
            w.scheduledDate.day == normalizedDate.day)
        .toList();
  }

  /// Check if a scheduled workout is completed for a specific date
  static Future<bool> isCompleted(String scheduledWorkoutId, DateTime date) async {
    final completed = await findCompleted(scheduledWorkoutId, date);
    return completed != null;
  }
}
