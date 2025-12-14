import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';

/// Service to handle saving and loading custom exercises
/// User-defined exercises override hardcoded defaults with same name
class ExerciseStorage {
  static const String _storageKey = 'custom_exercises';

  /// Load only user-defined exercises from storage
  static Future<List<Exercise>> loadCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all exercises (user-defined + defaults, with user overriding defaults)
  static Future<List<Exercise>> getAllExercises() async {
    final customExercises = await loadCustomExercises();
    final customNames = customExercises.map((e) => e.name.toLowerCase()).toSet();

    // Start with custom exercises
    final allExercises = <Exercise>[...customExercises];

    // Add defaults that aren't overridden
    for (final defaultEx in Exercise.defaults) {
      if (!customNames.contains(defaultEx.name.toLowerCase())) {
        allExercises.add(defaultEx);
      }
    }

    // Sort alphabetically
    allExercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return allExercises;
  }

  /// Get all exercise names for autocomplete
  static Future<List<String>> getAllNames() async {
    final exercises = await getAllExercises();
    return exercises.map((e) => e.name).toList();
  }

  /// Find exercise by name (checks custom first, then defaults)
  static Future<Exercise?> findByName(String name) async {
    final exercises = await getAllExercises();
    try {
      return exercises.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if a name already exists (case-insensitive)
  static Future<bool> nameExists(String name, {String? excludeId}) async {
    final exercises = await getAllExercises();
    return exercises.any(
      (e) => e.name.toLowerCase() == name.toLowerCase() && e.id != excludeId,
    );
  }

  /// Save custom exercises to storage
  static Future<void> _saveCustomExercises(List<Exercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = exercises.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Add a new custom exercise
  /// Returns false if name already exists in custom exercises
  static Future<bool> addExercise(Exercise exercise) async {
    final customExercises = await loadCustomExercises();

    // Check for duplicate names in custom exercises
    if (customExercises.any(
      (e) => e.name.toLowerCase() == exercise.name.toLowerCase(),
    )) {
      return false; // Duplicate name
    }

    customExercises.add(exercise);
    await _saveCustomExercises(customExercises);
    return true;
  }

  /// Update an existing custom exercise
  static Future<bool> updateExercise(Exercise exercise) async {
    final customExercises = await loadCustomExercises();

    // Check for duplicate names (excluding this exercise)
    if (customExercises.any(
      (e) => e.name.toLowerCase() == exercise.name.toLowerCase() && e.id != exercise.id,
    )) {
      return false; // Duplicate name
    }

    final index = customExercises.indexWhere((e) => e.id == exercise.id);
    if (index != -1) {
      customExercises[index] = exercise;
    } else {
      // If it was a default being overridden, add as new custom
      customExercises.add(exercise);
    }

    await _saveCustomExercises(customExercises);
    return true;
  }

  /// Delete a custom exercise (can't delete defaults, only remove overrides)
  static Future<void> deleteExercise(String id) async {
    final customExercises = await loadCustomExercises();
    customExercises.removeWhere((e) => e.id == id);
    await _saveCustomExercises(customExercises);
  }
}
