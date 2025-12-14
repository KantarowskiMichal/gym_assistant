import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_storage.dart';

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
    // Only show user-defined exercises (not hardcoded defaults)
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

  Future<void> _saveNewExercise(Exercise exercise) async {
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

  Future<void> _updateExercise(Exercise exercise) async {
    final success = await ExerciseStorage.updateExercise(exercise);
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
                // Info text
                Text(
                  'Define exercises with default values. These will be available when creating workouts.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // New exercise form
                if (_isAddingNew)
                  _ExerciseForm(
                    onSave: _saveNewExercise,
                    onCancel: _cancelEdit,
                  ),

                // Exercise list
                ..._exercises.map((exercise) {
                  final isExpanded = _expandedExerciseId == exercise.id;
                  return _ExerciseCard(
                    exercise: exercise,
                    isExpanded: isExpanded,
                    onTap: () => setState(() => _expandedExerciseId = exercise.id),
                    onSave: _updateExercise,
                    onCancel: _cancelEdit,
                    onDelete: () => _deleteExercise(exercise),
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

class _ExerciseForm extends StatefulWidget {
  final Exercise? exercise;
  final Function(Exercise) onSave;
  final VoidCallback onCancel;

  const _ExerciseForm({
    this.exercise,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<_ExerciseForm> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late ExerciseType _type;

  // Track if fields have been touched (for clearing defaults)
  bool _nameTouched = false;
  bool _setsTouched = false;
  bool _repsTouched = false;
  bool _weightTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final isEditing = e != null;

    _nameController = TextEditingController(text: e?.name ?? '');
    _setsController = TextEditingController(
      text: (e?.defaultSets ?? 4).toString(),
    );
    _repsController = TextEditingController(
      text: (e?.defaultRepsOrDuration ?? 10).toString(),
    );
    _weightController = TextEditingController(
      text: (e?.defaultWeight ?? 0).toString(),
    );
    _type = e?.type ?? ExerciseType.dynamic;

    // If editing, mark all as touched so we don't clear existing values
    if (isEditing) {
      _nameTouched = true;
      _setsTouched = true;
      _repsTouched = true;
      _weightTouched = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _clearFieldOnTap(TextEditingController controller, bool Function() isTouched, VoidCallback markTouched) {
    if (!isTouched()) {
      controller.clear();
      markTouched();
    }
  }

  void _onTypeChanged(ExerciseType newType) {
    if (newType != _type) {
      setState(() {
        _type = newType;
        // Update default reps/duration when type changes and reset touched flag
        _repsController.text = newType == ExerciseType.static ? '30' : '10';
        _repsTouched = false;
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final sets = int.tryParse(_setsController.text);
    final reps = int.tryParse(_repsController.text);
    final weight = double.tryParse(_weightController.text) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }

    if (sets == null || sets <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid sets')),
      );
      return;
    }

    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid reps/duration')),
      );
      return;
    }

    Exercise exercise;
    if (widget.exercise != null) {
      exercise = widget.exercise!.copyWith(
        name: name,
        type: _type,
        defaultSets: sets,
        defaultRepsOrDuration: reps,
        defaultWeight: weight,
      );
    } else {
      exercise = Exercise.create(
        name: name,
        type: _type,
        defaultSets: sets,
        defaultRepsOrDuration: reps,
        defaultWeight: weight,
      );
    }

    widget.onSave(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final isStatic = _type == ExerciseType.static;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              onTap: () => _clearFieldOnTap(
                _nameController,
                () => _nameTouched,
                () => _nameTouched = true,
              ),
              decoration: const InputDecoration(
                labelText: 'Exercise Name',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Type selector
            Row(
              children: [
                const Text('Type: '),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Dynamic'),
                  selected: _type == ExerciseType.dynamic,
                  onSelected: (s) {
                    if (s) _onTypeChanged(ExerciseType.dynamic);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Static'),
                  selected: _type == ExerciseType.static,
                  onSelected: (s) {
                    if (s) _onTypeChanged(ExerciseType.static);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Default values
            const Text('Default Values:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    onTap: () => _clearFieldOnTap(
                      _setsController,
                      () => _setsTouched,
                      () => _setsTouched = true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    onTap: () => _clearFieldOnTap(
                      _repsController,
                      () => _repsTouched,
                      () => _repsTouched = true,
                    ),
                    decoration: InputDecoration(
                      labelText: isStatic ? 'Seconds' : 'Reps',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onTap: () => _clearFieldOnTap(
                      _weightController,
                      () => _weightTouched,
                      () => _weightTouched = true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(widget.exercise != null ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(Exercise) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.isExpanded,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpanded) {
      return Stack(
        children: [
          _ExerciseForm(
            exercise: exercise,
            onSave: onSave,
            onCancel: onCancel,
          ),
          if (exercise.isCustom)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ),
        ],
      );
    }

    final isStatic = exercise.type == ExerciseType.static;

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
                      '${exercise.defaultSets} sets × ${exercise.defaultRepsOrDuration} ${exercise.repsOrDurationLabel}'
                      '${exercise.defaultWeight > 0 ? ' @ ${exercise.defaultWeight}kg' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(isStatic ? 'Static' : 'Dynamic'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: isStatic ? Colors.orange[100] : Colors.green[100],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
