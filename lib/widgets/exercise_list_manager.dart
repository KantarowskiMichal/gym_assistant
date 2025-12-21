import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../utils/exercise_utils.dart';
import 'exercise_form.dart';

/// Manages a list of exercises with add/edit/delete/expand functionality.
///
/// This widget consolidates shared exercise list management logic used in:
/// - WorkoutTemplateEditor (workouts_screen.dart)
/// - CompleteWorkoutDialog (complete_workout_dialog.dart)
///
/// Features:
/// - Add/edit/delete exercises
/// - Expand/collapse individual exercises for editing
/// - Configurable insert position (top or bottom)
/// - Configurable name editing in forms
/// - Compact card display when collapsed
class ExerciseListManager extends StatefulWidget {
  final List<PlannedExercise> initialExercises;
  final ValueChanged<List<PlannedExercise>> onExercisesChanged;
  final bool insertAtTop;
  final bool allowNameEditingInForm;
  final bool showRestAfterExercise;

  const ExerciseListManager({
    super.key,
    required this.initialExercises,
    required this.onExercisesChanged,
    this.insertAtTop = false,
    this.allowNameEditingInForm = true,
    this.showRestAfterExercise = false,
  });

  @override
  State<ExerciseListManager> createState() => ExerciseListManagerState();
}

class ExerciseListManagerState extends State<ExerciseListManager> {
  late List<PlannedExercise> _exercises;
  bool _isAddingExercise = false;
  int? _expandedExerciseIndex;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.initialExercises);
  }

  @override
  void didUpdateWidget(ExerciseListManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialExercises != widget.initialExercises) {
      _exercises = List.from(widget.initialExercises);
    }
  }

  void _addExercise(PlannedExercise exercise) {
    setState(() {
      if (widget.insertAtTop) {
        _exercises.insert(0, exercise);
      } else {
        _exercises.add(exercise);
      }
      _isAddingExercise = false;
    });
    widget.onExercisesChanged(_exercises);
  }

  void _updateExercise(int index, PlannedExercise exercise) {
    setState(() {
      _exercises[index] = exercise;
      _expandedExerciseIndex = null;
    });
    widget.onExercisesChanged(_exercises);
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _expandedExerciseIndex = null;
    });
    widget.onExercisesChanged(_exercises);
  }

  void _cancelEdit() {
    setState(() {
      _isAddingExercise = false;
      _expandedExerciseIndex = null;
    });
  }

  void _startAdding() {
    setState(() {
      _isAddingExercise = true;
      _expandedExerciseIndex = null;
    });
  }

  void _expandExercise(int index) {
    setState(() {
      _expandedExerciseIndex = index;
      _isAddingExercise = false;
    });
  }

  List<PlannedExercise> get exercises => List.unmodifiable(_exercises);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        if (_isAddingExercise) _buildAddForm(),
        if (_exercises.isEmpty && !_isAddingExercise) _buildEmptyState(),
        ..._buildExerciseItems(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold)),
        if (!_isAddingExercise)
          TextButton.icon(
            onPressed: _startAdding,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
      ],
    );
  }

  Widget _buildAddForm() {
    return ExerciseFormWidget(
      onSave: _addExercise,
      onCancel: _cancelEdit,
      showRestAfterExercise: widget.showRestAfterExercise,
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No exercises. Tap "Add" to add some.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  List<Widget> _buildExerciseItems() {
    return _exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;

      if (_expandedExerciseIndex == index) {
        return ExerciseFormWidget(
          exercise: exercise,
          onSave: (e) => _updateExercise(index, e),
          onCancel: _cancelEdit,
          onDelete: () => _removeExercise(index),
          showNameField: widget.allowNameEditingInForm,
          showRestAfterExercise: widget.showRestAfterExercise,
        );
      }

      return ExerciseCard(
        key: ValueKey(exercise.hashCode),
        exercise: exercise,
        onTap: () => _expandExercise(index),
        onRemove: () => _removeExercise(index),
      );
    }).toList();
  }
}

/// Compact card for displaying exercise in collapsed state.
///
/// This widget replaces both ExerciseCard (from exercise_form.dart) and
/// _CompactExerciseCard (from complete_workout_dialog.dart) which were 95% identical.
class ExerciseCard extends StatelessWidget {
  final PlannedExercise exercise;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    required this.onRemove,
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
              Expanded(child: _buildExerciseInfo()),
              _buildModeChip(),
              _buildRemoveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExerciseName(),
        const SizedBox(height: 2),
        _buildDisplayString(),
        if (exercise.restDisplayString.isNotEmpty) _buildRestBetweenSets(),
        if (_hasRestAfterExercise()) _buildRestAfterExercise(),
      ],
    );
  }

  Widget _buildExerciseName() {
    return Text(
      exercise.exerciseName,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDisplayString() {
    return Text(
      exercise.displayString,
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    );
  }

  Widget _buildRestBetweenSets() {
    return Text(
      'Rest: ${exercise.restDisplayString}',
      style: TextStyle(color: Colors.grey[500], fontSize: 11),
    );
  }

  bool _hasRestAfterExercise() {
    return exercise.restAfterExercise != null && exercise.restAfterExercise! > 0;
  }

  Widget _buildRestAfterExercise() {
    return Text(
      'Then rest: ${formatRestTime(exercise.restAfterExercise!)}',
      style: TextStyle(color: Colors.blue[400], fontSize: 11),
    );
  }

  Widget _buildModeChip() {
    return Chip(
      label: Text(exercise.modeLabel, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      backgroundColor: getModeColor(exercise.mode),
    );
  }

  Widget _buildRemoveButton() {
    return IconButton(
      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
      onPressed: onRemove,
      visualDensity: VisualDensity.compact,
      tooltip: 'Remove exercise',
    );
  }
}
