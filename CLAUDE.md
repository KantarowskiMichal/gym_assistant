# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter run              # Run the app
flutter test             # Run all tests
flutter analyze          # Static analysis
flutter pub get          # Install dependencies
```

## Architecture

Flutter workout planning app with three-tab navigation:

```
lib/
├── main.dart                    # App entry, MaterialApp, bottom navigation
├── models/
│   ├── exercise.dart            # Exercise model with hardcoded defaults
│   └── workout.dart             # Workout, PlannedExercise, RecurrenceType, WorkoutIcons
├── services/
│   ├── exercise_storage.dart    # SharedPreferences CRUD for exercises
│   └── workout_storage.dart     # Separate storage for templates vs scheduled
└── screens/
    ├── exercises_screen.dart    # Define custom exercises
    ├── workouts_screen.dart     # Create workout templates
    └── calendar_screen.dart     # Schedule workouts with recurrence
```

## Key Concepts

**Exercise Override System**: Hardcoded default exercises (Pull Ups, Push Ups, etc.) can be overridden by user-defined exercises with the same name. Only custom exercises are stored; defaults are merged at runtime.

**Template vs Scheduled Separation**: Workouts screen manages templates (`workout_templates` key). Calendar manages scheduled instances (`scheduled_workouts` key). Deleting a template also removes all scheduled instances with the same name.

**Exercise Types**: `dynamic` (counted in reps) vs `static` (measured in seconds). Affects default values and display labels.

## Specification

See `spec.md` for detailed data models, screen behaviors, and test specifications. Modify this file as the user requests new features or changes existing spec. keep the spec concise and well structured.

## Coding guidelines

Try to adhere to best coding practices, keep the code clean, readable and well structured.
