import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';

/// Service to handle saving and loading workouts
/// Separates workout templates from scheduled instances
class WorkoutStorage {
  static const String _templatesKey = 'workout_templates';
  static const String _scheduledKey = 'scheduled_workouts';

  // ============ TEMPLATES ============
  // Templates are workout definitions without scheduling info

  static Future<List<Workout>> loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_templatesKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Workout.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveTemplates(List<Workout> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = templates.map((w) => w.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_templatesKey, jsonString);
  }

  static Future<void> addTemplate(Workout template) async {
    final templates = await loadTemplates();
    templates.add(template);
    await saveTemplates(templates);
  }

  static Future<void> updateTemplate(Workout template) async {
    final templates = await loadTemplates();
    final index = templates.indexWhere((w) => w.id == template.id);
    if (index != -1) {
      templates[index] = template;
      await saveTemplates(templates);
    }
  }

  static Future<void> deleteTemplate(String id) async {
    final templates = await loadTemplates();
    final templateToDelete = templates.where((w) => w.id == id).firstOrNull;

    if (templateToDelete != null) {
      // Also delete all scheduled instances with the same name
      final scheduled = await loadScheduled();
      scheduled.removeWhere((w) => w.name == templateToDelete.name);
      await saveScheduled(scheduled);
    }

    templates.removeWhere((w) => w.id == id);
    await saveTemplates(templates);
  }

  // ============ SCHEDULED WORKOUTS ============
  // Scheduled workouts are instances with dates and recurrence

  static Future<List<Workout>> loadScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_scheduledKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Workout.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveScheduled(List<Workout> scheduled) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = scheduled.map((w) => w.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_scheduledKey, jsonString);
  }

  static Future<void> addScheduled(Workout workout) async {
    final scheduled = await loadScheduled();
    scheduled.add(workout);
    await saveScheduled(scheduled);
  }

  static Future<void> deleteScheduled(String id) async {
    final scheduled = await loadScheduled();
    scheduled.removeWhere((w) => w.id == id);
    await saveScheduled(scheduled);
  }

  /// Get all scheduled workouts that occur on a specific date
  static Future<List<Workout>> getScheduledForDate(DateTime date) async {
    final scheduled = await loadScheduled();
    return scheduled.where((w) => w.occursOn(date)).toList();
  }

  // ============ LEGACY MIGRATION ============
  // Migrate old 'workouts' key to new separated keys

  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final oldKey = 'workouts';
    final jsonString = prefs.getString(oldKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      // Check if we already migrated
      final hasTemplates = prefs.getString(_templatesKey);
      final hasScheduled = prefs.getString(_scheduledKey);

      if (hasTemplates == null && hasScheduled == null) {
        // Migrate old data - all old workouts become templates
        await prefs.setString(_templatesKey, jsonString);
        await prefs.remove(oldKey);
      }
    }
  }

}
