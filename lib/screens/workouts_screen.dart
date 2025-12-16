import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_storage.dart';
import '../widgets/exercise_form.dart';

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

/// Editor for workout templates
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
      builder: (context) => _IconPickerSheet(
        selectedIcon: _selectedIcon,
        onIconSelected: (icon) {
          setState(() => _selectedIcon = icon);
          Navigator.pop(context);
        },
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
        startDate: DateTime.now(),
        recurrenceType: RecurrenceType.oneOff,
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
            ExerciseFormWidget(
              onSave: _saveNewExercise,
              onCancel: _cancelEdit,
              showRestAfterExercise: true,
            ),

          ..._exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            final isExpanded = _expandedExerciseIndex == index;

            if (isExpanded) {
              return ExerciseFormWidget(
                exercise: exercise,
                onSave: (e) => _updateExercise(index, e),
                onCancel: _cancelEdit,
                onDelete: () => _deleteExercise(index),
                showRestAfterExercise: true,
              );
            }

            return ExerciseCard(
              exercise: exercise,
              onTap: () => setState(() => _expandedExerciseIndex = index),
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

class _IconPickerSheet extends StatelessWidget {
  final IconData selectedIcon;
  final ValueChanged<IconData> onIconSelected;

  const _IconPickerSheet({
    required this.selectedIcon,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: WorkoutIcons.available
                .map((icon) => _IconOption(
                      icon: icon,
                      isSelected: icon.codePoint == selectedIcon.codePoint,
                      onTap: () => onIconSelected(icon),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
  }
}
