import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/exercise_storage.dart';
import '../widgets/exercise_form.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<Exercise> _exercises = [];
  bool _isLoading = true;
  String? _expandedExerciseId;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await ExerciseStorage.loadCustomExercises();
    exercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _exercises = exercises;
      _isLoading = false;
    });
  }

  void _startAddingNew() {
    setState(() {
      _isAddingNew = true;
      _expandedExerciseId = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isAddingNew = false;
      _expandedExerciseId = null;
    });
  }

  Future<void> _saveNewExercise(PlannedExercise planned) async {
    // Convert PlannedExercise to Exercise
    final exercise = Exercise.create(
      name: planned.exerciseName,
      mode: planned.mode,
      defaultSets: planned.targetSets,
      defaultReps: planned.targetReps ?? 10,
      defaultRepsPerSet: planned.targetRepsPerSet,
      defaultPyramidTop: planned.pyramidTop ?? 10,
      defaultSeconds: planned.targetSeconds ?? 30,
      defaultWeight: planned.targetWeight,
      defaultRestBetweenSets: planned.restBetweenSets,
      defaultRestBetweenSetsPerSet: planned.restBetweenSetsPerSet,
    );

    final success = await ExerciseStorage.addExercise(exercise);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a custom exercise with this name')),
      );
      return;
    }
    setState(() => _isAddingNew = false);
    _loadExercises();
  }

  Future<void> _updateExercise(Exercise original, PlannedExercise planned) async {
    final updated = original.copyWith(
      name: planned.exerciseName,
      mode: planned.mode,
      defaultSets: planned.targetSets,
      defaultReps: planned.targetReps,
      defaultRepsPerSet: planned.targetRepsPerSet,
      defaultPyramidTop: planned.pyramidTop,
      defaultSeconds: planned.targetSeconds,
      defaultWeight: planned.targetWeight,
      defaultRestBetweenSets: planned.restBetweenSets,
      defaultRestBetweenSetsPerSet: planned.restBetweenSetsPerSet,
    );

    final success = await ExerciseStorage.updateExercise(updated);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have another custom exercise with this name')),
      );
      return;
    }
    setState(() => _expandedExerciseId = null);
    _loadExercises();
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    if (!exercise.isCustom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default exercises')),
      );
      return;
    }
    await ExerciseStorage.deleteExercise(exercise.id);
    setState(() => _expandedExerciseId = null);
    _loadExercises();
  }

  /// Convert Exercise to PlannedExercise for editing
  PlannedExercise _exerciseToPlanned(Exercise exercise) {
    return PlannedExercise(
      exerciseName: exercise.name,
      mode: exercise.mode,
      targetSets: exercise.defaultSets,
      targetReps: exercise.mode == ExerciseMode.reps ? exercise.defaultReps : null,
      targetRepsPerSet: exercise.mode == ExerciseMode.variableSets
          ? (exercise.defaultRepsPerSet ?? List.filled(exercise.defaultSets, exercise.defaultReps))
          : null,
      pyramidTop: exercise.mode == ExerciseMode.pyramid ? exercise.defaultPyramidTop : null,
      targetSeconds: exercise.mode == ExerciseMode.static ? exercise.defaultSeconds : null,
      targetWeight: exercise.defaultWeight,
      restBetweenSets: exercise.mode != ExerciseMode.variableSets ? exercise.defaultRestBetweenSets : null,
      restBetweenSetsPerSet: exercise.mode == ExerciseMode.variableSets
          ? (exercise.defaultRestBetweenSetsPerSet ?? (exercise.defaultRestBetweenSets != null
              ? List.filled(exercise.defaultSets, exercise.defaultRestBetweenSets!)
              : null))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Define exercises with default values. These will be available when creating workouts.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                if (_isAddingNew)
                  ExerciseFormWidget(
                    onSave: _saveNewExercise,
                    onCancel: _cancelEdit,
                    autoAddNewExercises: false,
                  ),

                ..._exercises.map((exercise) {
                  final isExpanded = _expandedExerciseId == exercise.id;

                  if (isExpanded) {
                    return ExerciseFormWidget(
                      exercise: _exerciseToPlanned(exercise),
                      onSave: (p) => _updateExercise(exercise, p),
                      onCancel: _cancelEdit,
                      onDelete: exercise.isCustom ? () => _deleteExercise(exercise) : null,
                      autoAddNewExercises: false,
                    );
                  }

                  return _ExerciseListCard(
                    exercise: exercise,
                    onTap: () => setState(() => _expandedExerciseId = exercise.id),
                  );
                }),
              ],
            ),
      floatingActionButton: _isAddingNew
          ? null
          : FloatingActionButton(
              onPressed: _startAddingNew,
              tooltip: 'Add Exercise',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ExerciseListCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseListCard({
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (!exercise.isCustom) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSummary(),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(exercise.modeLabel),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: _getModeColor(exercise.mode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSummary() {
    final weightSuffix = exercise.defaultWeight > 0 ? ' @ ${exercise.defaultWeight}kg' : '';
    return '${exercise.defaultsSummary}$weightSuffix';
  }

  Color? _getModeColor(ExerciseMode mode) {
    switch (mode) {
      case ExerciseMode.reps:
        return Colors.green[100];
      case ExerciseMode.variableSets:
        return Colors.blue[100];
      case ExerciseMode.pyramid:
        return Colors.purple[100];
      case ExerciseMode.static:
        return Colors.orange[100];
    }
  }
}
