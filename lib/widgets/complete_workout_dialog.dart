import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/completed_workout.dart';
import 'exercise_form.dart';
import 'rest_input.dart';

/// Dialog for completing or editing a completed workout.
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
  late List<PlannedExercise> _exercises;
  bool _isAddingExercise = false;
  int? _expandedExerciseIndex;

  @override
  void initState() {
    super.initState();
    final sourceExercises =
        widget.existingCompleted?.exercises ?? widget.workout.exercises;
    _exercises = List.from(sourceExercises);
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _expandedExerciseIndex = null;
    });
  }

  void _addExercise(PlannedExercise exercise) {
    setState(() {
      _exercises.insert(0, exercise);
      _isAddingExercise = false;
    });
  }

  void _updateExercise(int index, PlannedExercise exercise) {
    setState(() {
      _exercises[index] = exercise;
      _expandedExerciseIndex = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isAddingExercise = false;
      _expandedExerciseIndex = null;
    });
  }

  void _save() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    CompletedWorkout result;
    if (widget.existingCompleted != null) {
      result = widget.existingCompleted!.copyWith(
        exercises: _exercises,
        completedAt: DateTime.now(),
      );
    } else {
      result = CompletedWorkout.fromWorkout(
        widget.workout,
        widget.scheduledDate,
        modifiedExercises: _exercises,
      );
    }

    Navigator.pop(context, result);
  }

  bool get _isEditing => widget.existingCompleted != null;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 450,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Flexible(child: _buildExerciseList()),
              const Divider(),
              const SizedBox(height: 8),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildWorkoutIcon(),
        const SizedBox(width: 12),
        Expanded(child: _buildHeaderText()),
        _buildCloseButton(),
      ],
    );
  }

  Widget _buildWorkoutIcon() {
    return Container(
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
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit Completed Workout' : 'Complete Workout',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          widget.workout.name,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildExerciseList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExerciseListHeader(),
          const SizedBox(height: 8),
          if (_isAddingExercise)
            ExerciseFormWidget(
              onSave: _addExercise,
              onCancel: _cancelEdit,
              showRestAfterExercise: true,
            ),
          if (_exercises.isEmpty && !_isAddingExercise)
            _buildEmptyState(),
          ..._buildExerciseItems(),
        ],
      ),
    );
  }

  Widget _buildExerciseListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold)),
        if (!_isAddingExercise)
          TextButton.icon(
            onPressed: () => setState(() {
              _isAddingExercise = true;
              _expandedExerciseIndex = null;
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
      ],
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
          showNameField: false,
          showRestAfterExercise: true,
        );
      }

      return _CompactExerciseCard(
        exercise: exercise,
        onTap: () => setState(() {
          _expandedExerciseIndex = index;
          _isAddingExercise = false;
        }),
        onRemove: () => _removeExercise(index),
      );
    }).toList();
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save Changes' : 'Mark Complete'),
        ),
      ],
    );
  }
}

/// Compact card for displaying exercise in the completion dialog
class _CompactExerciseCard extends StatelessWidget {
  final PlannedExercise exercise;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CompactExerciseCard({
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
      backgroundColor: _getModeColor(exercise.mode),
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

  Color? _getModeColor(ExerciseMode mode) => switch (mode) {
    ExerciseMode.reps => Colors.green[100],
    ExerciseMode.variableSets => Colors.blue[100],
    ExerciseMode.pyramid => Colors.purple[100],
    ExerciseMode.static => Colors.orange[100],
  };
}
