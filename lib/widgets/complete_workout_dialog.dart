import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/completed_workout.dart';
import 'exercise_list_manager.dart';

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

  @override
  void initState() {
    super.initState();
    final sourceExercises =
        widget.existingCompleted?.exercises ?? widget.workout.exercises;
    _exercises = List.from(sourceExercises);
  }

  void _onExercisesChanged(List<PlannedExercise> exercises) {
    setState(() {
      _exercises = exercises;
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
      child: ExerciseListManager(
        initialExercises: _exercises,
        onExercisesChanged: _onExercisesChanged,
        insertAtTop: true,
        allowNameEditingInForm: false,
        showRestAfterExercise: true,
      ),
    );
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
