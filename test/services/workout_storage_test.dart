import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_assistant/models/workout.dart';
import 'package:gym_assistant/models/exercise.dart';
import 'package:gym_assistant/services/workout_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Templates', () {
    group('loadTemplates()', () {
      test('returns empty list when nothing stored', () async {
        final templates = await WorkoutStorage.loadTemplates();
        expect(templates, isEmpty);
      });

      test('returns stored templates', () async {
        final workout = Workout(
          id: 'template_id',
          name: 'Test Template',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([workout.toJson()]),
        });

        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(1));
        expect(templates.first.name, equals('Test Template'));
      });
    });

    group('addTemplate()', () {
      test('appends and saves template', () async {
        final workout = Workout(
          id: 'new_template',
          name: 'New Template',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        await WorkoutStorage.addTemplate(workout);

        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(1));
        expect(templates.first.name, equals('New Template'));
      });

      test('appends to existing templates', () async {
        final workout1 = Workout(
          id: 'template_1',
          name: 'Template 1',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([workout1.toJson()]),
        });

        final workout2 = Workout(
          id: 'template_2',
          name: 'Template 2',
          iconCodePoint: Icons.pool.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 16),
          recurrenceType: RecurrenceType.weekly,
        );

        await WorkoutStorage.addTemplate(workout2);

        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(2));
      });
    });

    group('updateTemplate()', () {
      test('updates by ID', () async {
        final workout = Workout(
          id: 'update_test',
          name: 'Original Name',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([workout.toJson()]),
        });

        final updated = Workout(
          id: 'update_test',
          name: 'Updated Name',
          iconCodePoint: Icons.pool.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        await WorkoutStorage.updateTemplate(updated);

        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(1));
        expect(templates.first.name, equals('Updated Name'));
        expect(templates.first.iconCodePoint, equals(Icons.pool.codePoint));
      });

      test('does nothing if ID not found', () async {
        final workout = Workout(
          id: 'existing_id',
          name: 'Existing',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([workout.toJson()]),
        });

        final nonExistent = Workout(
          id: 'nonexistent_id',
          name: 'Nonexistent',
          iconCodePoint: Icons.pool.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        await WorkoutStorage.updateTemplate(nonExistent);

        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(1));
        expect(templates.first.name, equals('Existing'));
      });
    });

    group('deleteTemplate()', () {
      test('removes template AND scheduled instances with same name', () async {
        final template = Workout(
          id: 'template_delete',
          name: 'Deletable Workout',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        final scheduled1 = Workout(
          id: 'scheduled_1',
          name: 'Deletable Workout', // Same name as template
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 20),
          recurrenceType: RecurrenceType.weekly,
        );

        final scheduled2 = Workout(
          id: 'scheduled_2',
          name: 'Other Workout', // Different name
          iconCodePoint: Icons.pool.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 25),
          recurrenceType: RecurrenceType.oneOff,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([template.toJson()]),
          'scheduled_workouts': jsonEncode([scheduled1.toJson(), scheduled2.toJson()]),
        });

        await WorkoutStorage.deleteTemplate(template.id);

        // Template should be gone
        final templates = await WorkoutStorage.loadTemplates();
        expect(templates, isEmpty);

        // Scheduled with same name should be gone, other should remain
        final scheduled = await WorkoutStorage.loadScheduled();
        expect(scheduled.length, equals(1));
        expect(scheduled.first.name, equals('Other Workout'));
      });

      test('preserves scheduled workouts with different names', () async {
        final template = Workout(
          id: 'template_id',
          name: 'Template Name',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        final scheduled = Workout(
          id: 'scheduled_id',
          name: 'Different Name',
          iconCodePoint: Icons.pool.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 20),
          recurrenceType: RecurrenceType.weekly,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([template.toJson()]),
          'scheduled_workouts': jsonEncode([scheduled.toJson()]),
        });

        await WorkoutStorage.deleteTemplate(template.id);

        final scheduledWorkouts = await WorkoutStorage.loadScheduled();
        expect(scheduledWorkouts.length, equals(1));
      });
    });
  });

  group('Scheduled', () {
    group('loadScheduled()', () {
      test('returns empty list when nothing stored', () async {
        final scheduled = await WorkoutStorage.loadScheduled();
        expect(scheduled, isEmpty);
      });

      test('returns stored scheduled workouts', () async {
        final workout = Workout(
          id: 'scheduled_test',
          name: 'Scheduled Workout',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.weekly,
        );

        SharedPreferences.setMockInitialValues({
          'scheduled_workouts': jsonEncode([workout.toJson()]),
        });

        final scheduled = await WorkoutStorage.loadScheduled();
        expect(scheduled.length, equals(1));
        expect(scheduled.first.name, equals('Scheduled Workout'));
      });
    });

    group('addScheduled()', () {
      test('appends and saves', () async {
        final workout = Workout(
          id: 'new_scheduled',
          name: 'New Scheduled',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.weekly,
        );

        await WorkoutStorage.addScheduled(workout);

        final scheduled = await WorkoutStorage.loadScheduled();
        expect(scheduled.length, equals(1));
        expect(scheduled.first.name, equals('New Scheduled'));
      });
    });

    group('deleteScheduled()', () {
      test('removes only that instance (not template)', () async {
        final template = Workout(
          id: 'template_id',
          name: 'My Workout',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 15),
          recurrenceType: RecurrenceType.oneOff,
        );

        final scheduled = Workout(
          id: 'scheduled_id',
          name: 'My Workout',
          iconCodePoint: Icons.fitness_center.codePoint,
          exercises: [],
          startDate: DateTime(2025, 1, 20),
          recurrenceType: RecurrenceType.weekly,
        );

        SharedPreferences.setMockInitialValues({
          'workout_templates': jsonEncode([template.toJson()]),
          'scheduled_workouts': jsonEncode([scheduled.toJson()]),
        });

        await WorkoutStorage.deleteScheduled(scheduled.id);

        // Scheduled should be gone
        final scheduledWorkouts = await WorkoutStorage.loadScheduled();
        expect(scheduledWorkouts, isEmpty);

        // Template should still exist
        final templates = await WorkoutStorage.loadTemplates();
        expect(templates.length, equals(1));
        expect(templates.first.name, equals('My Workout'));
      });
    });
  });

  group('getScheduledForDate()', () {
    test('returns workouts where occursOn(date) is true', () async {
      // One-off on Jan 15
      final oneOff = Workout(
        id: 'one_off',
        name: 'One-off',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      // Weekly on Wednesdays (Jan 15 is Wednesday)
      final weekly = Workout(
        id: 'weekly',
        name: 'Weekly',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.weekly,
      );

      SharedPreferences.setMockInitialValues({
        'scheduled_workouts': jsonEncode([oneOff.toJson(), weekly.toJson()]),
      });

      // Jan 15 - both should appear
      var workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 15));
      expect(workouts.length, equals(2));

      // Jan 22 - only weekly (next Wednesday)
      workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 22));
      expect(workouts.length, equals(1));
      expect(workouts.first.name, equals('Weekly'));

      // Jan 16 - neither
      workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 16));
      expect(workouts, isEmpty);
    });

    test('correctly filters offset type', () async {
      final offset = Workout(
        id: 'offset',
        name: 'Every 3 days',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 10),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      SharedPreferences.setMockInitialValues({
        'scheduled_workouts': jsonEncode([offset.toJson()]),
      });

      // Jan 10 - yes (start)
      var workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 10));
      expect(workouts.length, equals(1));

      // Jan 13 - yes (+3)
      workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 13));
      expect(workouts.length, equals(1));

      // Jan 11 - no
      workouts = await WorkoutStorage.getScheduledForDate(DateTime(2025, 1, 11));
      expect(workouts, isEmpty);
    });
  });

  group('migrateIfNeeded()', () {
    test('migrates old "workouts" key to workout_templates', () async {
      final oldWorkout = Workout(
        id: 'old_workout',
        name: 'Old Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      SharedPreferences.setMockInitialValues({
        'workouts': jsonEncode([oldWorkout.toJson()]),
      });

      await WorkoutStorage.migrateIfNeeded();

      // Should now be in workout_templates
      final templates = await WorkoutStorage.loadTemplates();
      expect(templates.length, equals(1));
      expect(templates.first.name, equals('Old Workout'));

      // Old key should be removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('workouts'), isNull);
    });

    test('does nothing if already migrated', () async {
      final oldWorkout = Workout(
        id: 'old',
        name: 'Old',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final newWorkout = Workout(
        id: 'new',
        name: 'New',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      SharedPreferences.setMockInitialValues({
        'workouts': jsonEncode([oldWorkout.toJson()]), // Old data
        'workout_templates': jsonEncode([newWorkout.toJson()]), // New data exists
      });

      await WorkoutStorage.migrateIfNeeded();

      // Should keep new data, not overwrite
      final templates = await WorkoutStorage.loadTemplates();
      expect(templates.length, equals(1));
      expect(templates.first.name, equals('New'));
    });

    test('does nothing if no old data exists', () async {
      SharedPreferences.setMockInitialValues({});

      await WorkoutStorage.migrateIfNeeded();

      final templates = await WorkoutStorage.loadTemplates();
      expect(templates, isEmpty);
    });
  });

  group('updateTemplateAndScheduled()', () {
    test('finds template by name (not ID)', () async {
      final template = Workout(
        id: 'template_id',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      SharedPreferences.setMockInitialValues({
        'workout_templates': jsonEncode([template.toJson()]),
        'scheduled_workouts': jsonEncode([]),
      });

      // Updated workout has different ID (like a scheduled instance would)
      final updated = Workout(
        id: 'different_id',
        name: 'Updated Workout',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'New Exercise',
            exerciseType: ExerciseType.dynamic,
            targetSets: 4,
            targetRepsOrDuration: 10,
          ),
        ],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      await WorkoutStorage.updateTemplateAndScheduled(updated, 'My Workout');

      final templates = await WorkoutStorage.loadTemplates();
      expect(templates.length, equals(1));
      expect(templates.first.name, equals('Updated Workout'));
      expect(templates.first.iconCodePoint, equals(Icons.pool.codePoint));
      expect(templates.first.exercises.length, equals(1));
      // Template ID should be preserved
      expect(templates.first.id, equals('template_id'));
    });

    test('syncs changes to all scheduled instances with same name', () async {
      final template = Workout(
        id: 'template_id',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final scheduled1 = Workout(
        id: 'scheduled_1',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 20),
        recurrenceType: RecurrenceType.weekly,
      );

      final scheduled2 = Workout(
        id: 'scheduled_2',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 25),
        recurrenceType: RecurrenceType.offset,
        offsetDays: 3,
      );

      final otherScheduled = Workout(
        id: 'other',
        name: 'Other Workout',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 30),
        recurrenceType: RecurrenceType.oneOff,
      );

      SharedPreferences.setMockInitialValues({
        'workout_templates': jsonEncode([template.toJson()]),
        'scheduled_workouts': jsonEncode([
          scheduled1.toJson(),
          scheduled2.toJson(),
          otherScheduled.toJson(),
        ]),
      });

      final updated = Workout(
        id: 'any_id',
        name: 'Renamed Workout',
        iconCodePoint: Icons.directions_run.codePoint,
        exercises: [
          PlannedExercise(
            exerciseName: 'Running',
            exerciseType: ExerciseType.dynamic,
            targetSets: 1,
            targetRepsOrDuration: 30,
          ),
        ],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      await WorkoutStorage.updateTemplateAndScheduled(updated, 'My Workout');

      final scheduled = await WorkoutStorage.loadScheduled();
      expect(scheduled.length, equals(3));

      // Both "My Workout" scheduled instances should be updated
      final myWorkouts = scheduled.where((w) => w.name == 'Renamed Workout').toList();
      expect(myWorkouts.length, equals(2));
      for (final w in myWorkouts) {
        expect(w.iconCodePoint, equals(Icons.directions_run.codePoint));
        expect(w.exercises.length, equals(1));
      }

      // Other workout should be unchanged
      final other = scheduled.firstWhere((w) => w.name == 'Other Workout');
      expect(other.iconCodePoint, equals(Icons.pool.codePoint));
    });

    test('preserves scheduled workout IDs', () async {
      final template = Workout(
        id: 'template_id',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      final scheduled = Workout(
        id: 'scheduled_id_to_preserve',
        name: 'My Workout',
        iconCodePoint: Icons.fitness_center.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 20),
        recurrenceType: RecurrenceType.weekly,
      );

      SharedPreferences.setMockInitialValues({
        'workout_templates': jsonEncode([template.toJson()]),
        'scheduled_workouts': jsonEncode([scheduled.toJson()]),
      });

      final updated = Workout(
        id: 'different_id',
        name: 'Updated Name',
        iconCodePoint: Icons.pool.codePoint,
        exercises: [],
        startDate: DateTime(2025, 1, 15),
        recurrenceType: RecurrenceType.oneOff,
      );

      await WorkoutStorage.updateTemplateAndScheduled(updated, 'My Workout');

      final scheduledWorkouts = await WorkoutStorage.loadScheduled();
      expect(scheduledWorkouts.first.id, equals('scheduled_id_to_preserve'));
      expect(scheduledWorkouts.first.name, equals('Updated Name'));
    });
  });
}
