import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import '../services/workout_storage.dart';
import '../services/exercise_storage.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    // Only load templates (not scheduled instances)
    final workouts = await WorkoutStorage.loadTemplates();
    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
  }

  Future<void> _addWorkout() async {
    final result = await Navigator.push<Workout>(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkoutTemplateEditor(),
      ),
    );

    if (result != null) {
      await WorkoutStorage.addTemplate(result);
      _loadWorkouts();
    }
  }

  Future<void> _editWorkout(Workout workout) async {
    final result = await Navigator.push<Workout>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutTemplateEditor(existingWorkout: workout),
      ),
    );

    if (result != null) {
      await WorkoutStorage.updateTemplate(result);
      _loadWorkouts();
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Delete "${workout.name}"? This will also remove all scheduled instances from the calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WorkoutStorage.deleteTemplate(workout.id);
      _loadWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? const Center(
                  child: Text(
                    'No workouts yet.\nTap + to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    return _WorkoutCard(
                      workout: workout,
                      onTap: () => _editWorkout(workout),
                      onDelete: () => _deleteWorkout(workout),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWorkout,
        tooltip: 'Add Workout',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  workout.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${workout.exercises.length} exercise${workout.exercises.length != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (workout.exercises.isNotEmpty)
                      Text(
                        workout.exercises.map((e) => e.exerciseName).join(', '),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editor for workout templates (no recurrence - that's set in calendar)
class WorkoutTemplateEditor extends StatefulWidget {
  final Workout? existingWorkout;

  const WorkoutTemplateEditor({super.key, this.existingWorkout});

  bool get isEditing => existingWorkout != null;

  @override
  State<WorkoutTemplateEditor> createState() => _WorkoutTemplateEditorState();
}

class _WorkoutTemplateEditorState extends State<WorkoutTemplateEditor> {
  late TextEditingController _nameController;
  late IconData _selectedIcon;
  late List<PlannedExercise> _exercises;
  int? _expandedExerciseIndex;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    final workout = widget.existingWorkout;
    _nameController = TextEditingController(text: workout?.name ?? '');
    _selectedIcon = workout?.icon ?? WorkoutIcons.defaultIcon;
    _exercises = workout?.exercises.toList() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Icon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: WorkoutIcons.available.map((icon) {
                final isSelected = icon.codePoint == _selectedIcon.codePoint;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _addExercise() {
    setState(() {
      _isAddingNew = true;
      _expandedExerciseIndex = null;
    });
  }

  void _saveNewExercise(PlannedExercise exercise) {
    setState(() {
      _exercises.add(exercise);
      _isAddingNew = false;
    });
  }

  void _updateExercise(int index, PlannedExercise exercise) {
    setState(() {
      _exercises[index] = exercise;
      _expandedExerciseIndex = null;
    });
  }

  void _deleteExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _expandedExerciseIndex = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isAddingNew = false;
      _expandedExerciseIndex = null;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    Workout workout;
    if (widget.existingWorkout != null) {
      workout = widget.existingWorkout!.copyWith(
        name: name,
        icon: _selectedIcon,
        exercises: _exercises,
      );
    } else {
      workout = Workout.create(
        name: name,
        icon: _selectedIcon,
        startDate: DateTime.now(), // Will be overridden when scheduled
        recurrenceType: RecurrenceType.oneOff, // Will be set in calendar
        exercises: _exercises,
      );
    }

    Navigator.pop(context, workout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Workout' : 'New Workout'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name and icon row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    _selectedIcon,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Workout Name',
                    hintText: 'e.g., Push Day, Leg Day',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Exercises section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isAddingNew)
            _PlannedExerciseForm(
              onSave: _saveNewExercise,
              onCancel: _cancelEdit,
            ),

          ..._exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            final isExpanded = _expandedExerciseIndex == index;

            return _PlannedExerciseCard(
              exercise: exercise,
              isExpanded: isExpanded,
              onTap: () => setState(() => _expandedExerciseIndex = index),
              onSave: (e) => _updateExercise(index, e),
              onCancel: _cancelEdit,
              onDelete: () => _deleteExercise(index),
            );
          }),

          if (_exercises.isEmpty && !_isAddingNew)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No exercises yet.\nTap "Add" to add exercises.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlannedExerciseForm extends StatefulWidget {
  final PlannedExercise? exercise;
  final Function(PlannedExercise) onSave;
  final VoidCallback onCancel;

  const _PlannedExerciseForm({
    this.exercise,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_PlannedExerciseForm> createState() => _PlannedExerciseFormState();
}

class _PlannedExerciseFormState extends State<_PlannedExerciseForm> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late ExerciseType _type;
  List<Exercise> _allExercises = [];

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final isEditing = e != null;

    _nameController = TextEditingController(text: e?.exerciseName ?? '');
    _setsController = TextEditingController(
      text: isEditing ? e.targetSets.toString() : '',
    );
    _repsController = TextEditingController(
      text: isEditing ? e.targetRepsOrDuration.toString() : '',
    );
    _weightController = TextEditingController(
      text: isEditing ? e.targetWeight.toString() : '',
    );
    _type = e?.exerciseType ?? ExerciseType.dynamic;

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

    // Check if this is a new unique exercise name
    final existingExercise = await ExerciseStorage.findByName(name);
    if (existingExercise == null) {
      // New exercise - auto-add to exercises list with these values as defaults
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _nameController.text),
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
                const SizedBox(width: 12),
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedExerciseCard extends StatelessWidget {
  final PlannedExercise exercise;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(PlannedExercise) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _PlannedExerciseCard({
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
          _PlannedExerciseForm(
            exercise: exercise,
            onSave: onSave,
            onCancel: onCancel,
          ),
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

    final isStatic = exercise.exerciseType == ExerciseType.static;

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
                    Text(
                      exercise.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${exercise.targetSets} sets × ${exercise.targetRepsOrDuration} ${exercise.repsOrDurationLabel}'
                      '${exercise.targetWeight > 0 ? ' @ ${exercise.targetWeight}kg' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(isStatic ? 'Static' : 'Dynamic'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
