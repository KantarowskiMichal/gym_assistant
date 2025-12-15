import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/completed_workout.dart';
import '../services/exercise_storage.dart';

/// Dialog for completing or editing a completed workout.
/// Allows users to modify exercise data before saving.
class CompleteWorkoutDialog extends StatefulWidget {
  final Workout workout;
  final DateTime scheduledDate;
  final CompletedWorkout? existingCompleted;

  const CompleteWorkoutDialog({
    super.key,
    required this.workout,
    required this.scheduledDate,
    this.existingCompleted,
  });

  @override
  State<CompleteWorkoutDialog> createState() => _CompleteWorkoutDialogState();
}

class _CompleteWorkoutDialogState extends State<CompleteWorkoutDialog> {
  late List<_EditableExercise> _exercises;
  bool _isAddingExercise = false;

  @override
  void initState() {
    super.initState();
    _initExercises();
  }

  void _initExercises() {
    final sourceExercises = widget.existingCompleted?.exercises ?? widget.workout.exercises;
    _exercises = sourceExercises.map((e) => _EditableExercise.fromPlannedExercise(e)).toList();
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _addExercise(PlannedExercise exercise) {
    setState(() {
      // Insert at top of list
      _exercises.insert(0, _EditableExercise(
        name: exercise.exerciseName,
        type: exercise.exerciseType,
        setsController: TextEditingController(text: exercise.targetSets.toString()),
        repsController: TextEditingController(text: exercise.targetRepsOrDuration.toString()),
        weightController: TextEditingController(text: exercise.targetWeight.toString()),
      ));
      _isAddingExercise = false;
    });
  }

  void _save() {
    // Validate all exercises have valid values
    for (final exercise in _exercises) {
      final sets = int.tryParse(exercise.setsController.text);
      final reps = int.tryParse(exercise.repsController.text);
      if (sets == null || sets <= 0 || reps == null || reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid values for all exercises')),
        );
        return;
      }
    }

    final completedExercises = _exercises.map((e) => PlannedExercise(
      exerciseName: e.name,
      exerciseType: e.type,
      targetSets: int.parse(e.setsController.text),
      targetRepsOrDuration: int.parse(e.repsController.text),
      targetWeight: double.tryParse(e.weightController.text) ?? 0,
    )).toList();

    CompletedWorkout result;
    if (widget.existingCompleted != null) {
      result = widget.existingCompleted!.copyWith(
        exercises: completedExercises,
        completedAt: DateTime.now(),
      );
    } else {
      result = CompletedWorkout.fromWorkout(
        widget.workout,
        widget.scheduledDate,
        modifiedExercises: completedExercises,
      );
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCompleted != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.workout.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Completed Workout' : 'Complete Workout',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.workout.name,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Exercise list
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Exercises',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (!_isAddingExercise)
                            TextButton.icon(
                              onPressed: () => setState(() => _isAddingExercise = true),
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Add exercise form at top
                      if (_isAddingExercise)
                        _AddExerciseForm(
                          onSave: _addExercise,
                          onCancel: () => setState(() => _isAddingExercise = false),
                        ),

                      if (_exercises.isEmpty && !_isAddingExercise)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No exercises. Tap "Add" to add some.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),

                      ..._exercises.asMap().entries.map((entry) {
                        final index = entry.key;
                        final exercise = entry.value;
                        return _ExerciseEditCard(
                          exercise: exercise,
                          onRemove: () => _removeExercise(index),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const Divider(),
              const SizedBox(height: 8),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Mark Complete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableExercise {
  final String name;
  final ExerciseType type;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;

  _EditableExercise({
    required this.name,
    required this.type,
    required this.setsController,
    required this.repsController,
    required this.weightController,
  });

  factory _EditableExercise.fromPlannedExercise(PlannedExercise exercise) {
    return _EditableExercise(
      name: exercise.exerciseName,
      type: exercise.exerciseType,
      setsController: TextEditingController(text: exercise.targetSets.toString()),
      repsController: TextEditingController(text: exercise.targetRepsOrDuration.toString()),
      weightController: TextEditingController(text: exercise.targetWeight.toString()),
    );
  }

  void dispose() {
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
  }

  String get repsLabel => type == ExerciseType.dynamic ? 'Reps' : 'Seconds';
}

class _ExerciseEditCard extends StatelessWidget {
  final _EditableExercise exercise;
  final VoidCallback onRemove;

  const _ExerciseEditCard({
    required this.exercise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    exercise.type == ExerciseType.static ? 'Static' : 'Dynamic',
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove exercise',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise.setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: exercise.repsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: exercise.repsLabel,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: exercise.weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExerciseForm extends StatefulWidget {
  final Function(PlannedExercise) onSave;
  final VoidCallback onCancel;

  const _AddExerciseForm({
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_AddExerciseForm> createState() => _AddExerciseFormState();
}

class _AddExerciseFormState extends State<_AddExerciseForm> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  ExerciseType _type = ExerciseType.dynamic;
  List<Exercise> _allExercises = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _setsController = TextEditingController();
    _repsController = TextEditingController();
    _weightController = TextEditingController(text: '0');
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await ExerciseStorage.getAllExercises();
    setState(() => _allExercises = exercises);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onExerciseSelected(String name) async {
    final exercise = await ExerciseStorage.findByName(name);
    if (exercise != null) {
      setState(() {
        _type = exercise.type;
        _setsController.text = exercise.defaultSets.toString();
        _repsController.text = exercise.defaultRepsOrDuration.toString();
        _weightController.text = exercise.defaultWeight.toString();
      });
    }
  }

  void _submit() async {
    final name = _nameController.text.trim();
    final sets = int.tryParse(_setsController.text);
    final reps = int.tryParse(_repsController.text);
    final weight = double.tryParse(_weightController.text) ?? 0;

    if (name.isEmpty || sets == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in name, sets, and reps/duration')),
      );
      return;
    }

    // Check if this is a new unique exercise name - auto-add to custom exercises
    final existingExercise = await ExerciseStorage.findByName(name);
    if (existingExercise == null) {
      final newExercise = Exercise.create(
        name: name,
        type: _type,
        defaultSets: sets,
        defaultRepsOrDuration: reps,
        defaultWeight: weight,
      );
      await ExerciseStorage.addExercise(newExercise);
    }

    widget.onSave(PlannedExercise(
      exerciseName: name,
      exerciseType: _type,
      targetSets: sets,
      targetRepsOrDuration: reps,
      targetWeight: weight,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isStatic = _type == ExerciseType.static;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('New Exercise', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (value) {
                if (value.text.isEmpty) {
                  return _allExercises.map((e) => e.name);
                }
                return _allExercises
                    .map((e) => e.name)
                    .where((n) => n.toLowerCase().contains(value.text.toLowerCase()));
              },
              onSelected: (name) {
                _nameController.text = name;
                _onExerciseSelected(name);
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                    isDense: true,
                  ),
                  onChanged: (value) => _nameController.text = value,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Type: '),
                ChoiceChip(
                  label: const Text('Dynamic'),
                  selected: _type == ExerciseType.dynamic,
                  onSelected: (s) {
                    if (s) setState(() => _type = ExerciseType.dynamic);
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Static'),
                  selected: _type == ExerciseType.static,
                  onSelected: (s) {
                    if (s) setState(() => _type = ExerciseType.static);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isStatic ? 'Seconds' : 'Reps',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
