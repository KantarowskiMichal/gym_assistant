# Gym Assistant - Specification

## Overview

A workout planning app with four main screens: Exercises, Workouts, Today, and Calendar.

---

## Data Models

### Exercise

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier |
| name | String | Exercise name (unique, case-insensitive) |
| type | Enum | `dynamic` (reps) or `static` (duration) |
| defaultSets | int | Default sets (default: 4) |
| defaultRepsOrDuration | int | Default reps (10) or seconds (30) |
| defaultWeight | double | Default weight in kg (default: 0) |

**Hardcoded Defaults:**
- Pull Ups, Push Ups, Dips, Leg Press, Bench Press, Dead Lift (dynamic, 4x10)
- Planche, Dead Hang, Front Lever, Back Lever (static, 4x30s)

### Workout

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier |
| name | String | Workout name |
| iconCodePoint | int | Material icon code point |
| exercises | List | Planned exercises with target values |

### ScheduledWorkout

Extends Workout with scheduling:

| Field | Type | Description |
|-------|------|-------------|
| startDate | DateTime | First occurrence date |
| recurrenceType | Enum | `oneOff`, `weekly`, or `offset` |
| offsetDays | int? | Days between occurrences (for offset type) |

### CompletedWorkout

Snapshot of a workout when marked complete:

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier |
| scheduledWorkoutId | String | Reference to original scheduled workout |
| workoutName | String | Name (preserved even if template deleted) |
| iconCodePoint | int | Icon (preserved) |
| exercises | List | Exercises snapshot with actual values |
| scheduledDate | DateTime | The date it was scheduled for |
| completedAt | DateTime | When user marked it complete |

**Key Behavior:**
- Completed workouts are SNAPSHOTS - they preserve workout data at time of completion
- User can modify exercise data (sets, reps, weight) before saving completion
- User can edit a completed workout at any later time
- Completion is tracked per (scheduledWorkoutId + scheduledDate) pair
- Deleting a workout template does NOT delete completed workout records

---

## Screens

### 1. Exercises Screen

**Purpose:** Define custom exercises with default values.

**Display Rules:**
- Show only user-defined exercises
- Do NOT show hardcoded defaults
- Show overrides (user exercise with same name as default)

**Validation:**
- No duplicate names (case-insensitive)
- User-defined exercises override hardcoded defaults with same name

### 2. Workouts Screen

**Purpose:** Create workout templates (collections of exercises).

**Behavior:**
- Workouts are templates only, not scheduled
- Deleting a workout removes the template AND all scheduled instances from calendar

**Exercise Autocomplete:**
- Shows all exercises (user-defined + defaults)
- Auto-fills type, sets, reps/duration, weight from exercise definition
- Modifications to values in workout do NOT update exercise definition

**New Exercise Creation:**
- If exercise name is new (not default, not user-defined):
  - Automatically add to exercises list
  - Use entered values as defaults

### 3. Today Screen

**Purpose:** View and complete today's scheduled workouts.

**Display:**
- Shows all workouts scheduled for current date
- Visual indication for completed vs pending workouts
- Green checkmark and different background for completed workouts

**Completion Workflow:**
- Tap workout card: Opens completion dialog
- Tap checkbox: Toggles completion status
- On complete: Opens dialog to optionally modify exercise data (sets, reps, weight)
- Can add/remove exercises before completing
- Can edit completed workouts later by tapping again

**Uncomplete:**
- Tapping checkbox on completed workout removes completion record

### 4. Calendar Screen

**Purpose:** Schedule workouts on specific dates and track completion.

**Scheduling:**
- Select date, pick existing workout template
- Set recurrence: one-off, weekly, or every X days
- Creates a scheduled instance (copy of template)

**Display:**
- Shows workout icons on calendar days
- Lists scheduled workouts for selected day
- Visual indication for completed workouts (green border, checkmark)
- Days with all workouts completed show green background

**Completion:**
- Can mark workouts complete from any date (not just today)
- Same completion workflow as Today screen

**Removal:**
- Removing from calendar removes scheduled instance only
- Does NOT remove workout template from Workouts screen
- Does NOT remove completed workout records

---

## Storage

### Exercise Storage

- Key: `custom_exercises`
- Stores: User-defined exercises only
- Merge logic: User exercises override defaults by name

### Workout Storage

Two separate collections:

| Key | Content |
|-----|---------|
| `workout_templates` | Workout templates (no dates) |
| `scheduled_workouts` | Scheduled instances (with dates/recurrence) |

### Completed Workout Storage

| Key | Content |
|-----|---------|
| `completed_workouts` | Archived completed workout records |

**Behavior:**
- Separate from scheduled workouts (preserved even if template deleted)
- Used for history and future analytics features

---

## Icon Selection

Available workout icons:
- Strength: fitness_center, sports_kabaddi, sports_gymnastics, sports_martial_arts
- Cardio: directions_run, directions_bike, rowing, pool
- Flexibility: self_improvement, accessibility_new, airline_seat_legroom_extra, sports_handball
- General: flash_on, local_fire_department, timer, speed, trending_up, bolt
- Achievement: sports, sports_score, emoji_events, military_tech, star, favorite

---

## Recurrence Types

| Type | Behavior |
|------|----------|
| One-off | Single occurrence on selected date |
| Weekly | Repeats every week on same weekday |
| Offset | Repeats every N days from start date |

---

## Class Flows (Test Specifications)

### Exercise

```
Exercise.create(name, type)
  → generates unique id (timestamp-based)
  → defaultRepsOrDuration = 30 if static, 10 if dynamic
  → defaultSets = 4
  → defaultWeight = 0

Exercise.isCustom
  → true if id does NOT start with "default_"
  → false if id starts with "default_"

Exercise.fromJson → toJson
  → roundtrip preserves all fields
```

### ExerciseStorage

```
loadCustomExercises()
  → returns only user-defined exercises
  → returns empty list if none stored

getAllExercises()
  → returns user-defined + defaults
  → user exercises with same name (case-insensitive) override defaults
  → sorted alphabetically by name

findByName(name)
  → case-insensitive match
  → returns user-defined first if exists
  → returns default if no user override
  → returns null if not found

addExercise(exercise)
  → returns false if name already exists in custom exercises (case-insensitive)
  → returns true and saves if name is unique
  → can add exercise with same name as default (creates override)

updateExercise(exercise)
  → returns false if new name conflicts with another custom exercise
  → updates existing by id
  → if id not found in custom, adds as new (override scenario)

deleteExercise(id)
  → removes from custom exercises
  → does not affect defaults
```

### Workout

```
Workout.create(name, startDate, recurrenceType)
  → generates unique id (timestamp-based)
  → uses default icon if none provided

Workout.occursOn(date)
  → false if date is before startDate

  RecurrenceType.oneOff:
    → true only on exact startDate
    → false on all other dates

  RecurrenceType.weekly:
    → true if same weekday as startDate
    → true even weeks/months later
    → false if different weekday

  RecurrenceType.offset (N days):
    → true on startDate (day 0)
    → true on startDate + N days
    → true on startDate + 2N days
    → false on startDate + 1 (if N > 1)
    → false if offsetDays is null or <= 0

Workout.fromJson → toJson
  → roundtrip preserves all fields including exercises list
```

### PlannedExercise

```
PlannedExercise(name, type, sets, reps, weight?)
  → stores target values for workout template
  → does not reference Exercise by id, only by name

PlannedExercise.fromJson → toJson
  → roundtrip preserves all fields
```

### WorkoutStorage

```
Templates (workout_templates key):
  loadTemplates() → returns workout templates only
  addTemplate(w) → appends to templates list
  updateTemplate(w) → updates by id in templates
  deleteTemplate(id) → removes from templates AND all scheduled with same name
                    → does NOT affect completed_workouts (preserved for history)

Scheduled (scheduled_workouts key):
  loadScheduled() → returns scheduled instances only
  addScheduled(w) → appends to scheduled list
  deleteScheduled(id) → removes from scheduled only

getScheduledForDate(date)
  → filters scheduled workouts where occursOn(date) is true

migrateIfNeeded()
  → if old "workouts" key exists and new keys don't:
    → moves old data to workout_templates
    → removes old key
  → if already migrated, does nothing
```

### CompletedWorkout

```
CompletedWorkout.fromWorkout(workout, scheduledDate, {modifiedExercises})
  → generates unique id (timestamp-based)
  → copies workout name, icon, exercises (or uses modifiedExercises if provided)
  → stores scheduledWorkoutId reference
  → sets completedAt to now

CompletedWorkout.copyWith(...)
  → returns new instance with updated fields
  → used for editing completed workouts

CompletedWorkout.fromJson → toJson
  → roundtrip preserves all fields
```

### CompletedWorkoutStorage

```
loadAll()
  → returns all completed workout records
  → returns empty list if none stored

addCompleted(workout)
  → appends to completed list
  → saves to storage

updateCompleted(workout)
  → updates existing by id
  → used for editing completed workouts

deleteCompleted(id)
  → removes from completed list by id

findCompleted(scheduledWorkoutId, date)
  → returns completed workout matching both scheduledWorkoutId AND date
  → returns null if not found

getCompletedForDate(date)
  → returns all completed workouts for a specific date

isCompleted(scheduledWorkoutId, date)
  → returns true if workout is completed for that date
  → returns false otherwise
```

### Screen Flows

```
ExercisesScreen:
  onLoad → loadCustomExercises() (not defaults)
  onAdd → addExercise() → reload list
  onUpdate → updateExercise() → reload list
  onDelete → deleteExercise() → reload list (only custom allowed)

  Form field behavior (new exercise only):
    → Shows defaults (4 sets, 10/30 reps, 0 weight)
    → First tap on any field: clears value so user can type fresh
    → Subsequent taps: no clearing
    → When type changes: reps field resets to new default and will clear on next tap
    → Editing existing: values preserved, no auto-clear

WorkoutsScreen:
  onLoad → loadTemplates()
  onAdd → addTemplate() → reload list
  onEdit → updateTemplate() → reload list
  onDelete → deleteTemplate() (also removes all scheduled instances with same name)

  ExerciseForm.onSave:
    → if exercise name not in getAllExercises():
      → auto-add to custom exercises with entered values

  Form field behavior:
    → New exercise: fields start empty, no auto-clear needed
    → After autocomplete selection: fills defaults, no auto-clear
    → Editing existing: values preserved, no auto-clear

TodayScreen:
  onLoad → getScheduledForDate(today) + getCompletedForDate(today)
  onTapWorkout → opens CompleteWorkoutDialog
  onToggleComplete:
    → if not completed: opens CompleteWorkoutDialog
    → if completed: deleteCompleted()

  CompleteWorkoutDialog:
    → shows editable exercise list (sets, reps, weight)
    → can remove exercises or add from available exercises
    → on save: creates CompletedWorkout with modified values

CalendarScreen:
  onLoad → loadTemplates() + loadScheduled() + loadAll() (completed)
  onSchedule:
    → pick template from loadTemplates()
    → create new Workout with new id, selected date, recurrence
    → addScheduled() → reload
  onRemove → deleteScheduled() (does not affect template or completed)
  onTapWorkout → opens CompleteWorkoutDialog for selected date
  onToggleComplete → same as TodayScreen but for selected date

  Schedule dialog:
    → offset days defaults to 1
    → first tap on offset field: clears value for fresh input

  CalendarGrid:
    → for each day: getScheduledForDate() or filter locally
    → show icons of matching workouts
    → show green indicators for completed workouts
    → show checkmark if all workouts for day are completed
```
