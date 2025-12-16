import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/exercise_storage.dart';
import '../utils/input_formatters.dart';
import 'per_set_reps_input.dart';
import 'rest_input.dart';
import 'per_set_rest_input.dart';

/// Unified exercise form widget used across the app.
/// Adapts UI based on ExerciseMode.
class ExerciseFormWidget extends StatefulWidget {
  final PlannedExercise? exercise;
  final Function(PlannedExercise) onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  final bool showNameField;
  final bool autoAddNewExercises;
  final bool showRestAfterExercise; // Show rest after this exercise input

  const ExerciseFormWidget({
    super.key,
    this.exercise,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.showNameField = true,
    this.autoAddNewExercises = true,
    this.showRestAfterExercise = false,
  });

  @override
  State<ExerciseFormWidget> createState() => _ExerciseFormWidgetState();
}

class _ExerciseFormWidgetState extends State<ExerciseFormWidget> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _pyramidTopController;
  late TextEditingController _secondsController;
  late TextEditingController _weightController;
  late ExerciseMode _mode;

  List<Exercise> _allExercises = [];
  final _repsInputKey = GlobalKey<PerSetRepsInputState>();
  final _restInputKey = GlobalKey<RestInputState>();
  final _perSetRestInputKey = GlobalKey<PerSetRestInputState>();
  final _restAfterExerciseKey = GlobalKey<RestInputState>();
  int _setCount = 0;
  List<int> _initialRepsPerSet = [];
  int _initialRestBetweenSets = 0;
  List<int> _initialRestPerSet = [];
  int _initialRestAfterExercise = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final isEditing = e != null;

    _nameController = TextEditingController(text: e?.exerciseName ?? '');
    _mode = e?.mode ?? ExerciseMode.reps;
    _setsController = TextEditingController(
      text: isEditing ? e.targetSets.toString() : '',
    );
    _repsController = TextEditingController(
      text: isEditing && e.mode == ExerciseMode.reps ? (e.targetReps?.toString() ?? '') : '',
    );
    _pyramidTopController = TextEditingController(
      text: isEditing && e.mode == ExerciseMode.pyramid ? (e.pyramidTop?.toString() ?? '') : '',
    );
    _secondsController = TextEditingController(
      text: isEditing && e.mode == ExerciseMode.static ? (e.targetSeconds?.toString() ?? '') : '',
    );
    _weightController = TextEditingController(
      text: isEditing ? e.targetWeight.toString() : '',
    );

    if (isEditing && e.mode == ExerciseMode.variableSets) {
      _setCount = e.targetSets;
      _initialRepsPerSet = List<int>.from(e.targetRepsPerSet ?? []);
      _initialRestPerSet = List<int>.from(e.restBetweenSetsPerSet ?? []);
    } else if (isEditing) {
      _setCount = e.targetSets;
      _initialRestBetweenSets = e.restBetweenSets ?? 0;
    }

    if (isEditing) {
      _initialRestAfterExercise = e.restAfterExercise ?? 0;
    }

    _setsController.addListener(_onSetsChanged);
    _loadExercises();
  }

  void _onSetsChanged() {
    final sets = int.tryParse(_setsController.text) ?? 0;
    if (sets <= 0 || sets > 20) return;
    setState(() => _setCount = sets);
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
    _pyramidTopController.dispose();
    _secondsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onExerciseSelected(String name) async {
    final exercise = await ExerciseStorage.findByName(name);
    if (exercise != null) {
      setState(() {
        _mode = exercise.mode;
        _setsController.text = exercise.defaultSets.toString();
        _repsController.text = exercise.defaultReps.toString();
        _pyramidTopController.text = exercise.defaultPyramidTop.toString();
        _secondsController.text = exercise.defaultSeconds.toString();
        _weightController.text = exercise.defaultWeight.toString();
        _setCount = exercise.defaultSets;
        // Use stored per-set values if available, otherwise fill with default reps
        _initialRepsPerSet = exercise.defaultRepsPerSet != null
            ? List<int>.from(exercise.defaultRepsPerSet!)
            : List.filled(exercise.defaultSets, exercise.defaultReps);
        // Set rest values
        _initialRestBetweenSets = exercise.defaultRestBetweenSets ?? 0;
        _initialRestPerSet = exercise.defaultRestBetweenSetsPerSet != null
            ? List<int>.from(exercise.defaultRestBetweenSetsPerSet!)
            : [];
      });
      Future.delayed(Duration.zero, () {
        // Update per-set reps
        if (exercise.defaultRepsPerSet != null && exercise.defaultRepsPerSet!.isNotEmpty) {
          _repsInputKey.currentState?.setValues(exercise.defaultRepsPerSet!);
        } else {
          _repsInputKey.currentState?.fillAllWith(exercise.defaultReps);
        }
        // Update rest input based on mode
        if (exercise.mode == ExerciseMode.variableSets) {
          if (exercise.defaultRestBetweenSetsPerSet != null &&
              exercise.defaultRestBetweenSetsPerSet!.isNotEmpty) {
            _perSetRestInputKey.currentState?.setValues(exercise.defaultRestBetweenSetsPerSet!);
          } else if (exercise.defaultRestBetweenSets != null && exercise.defaultRestBetweenSets! > 0) {
            _perSetRestInputKey.currentState?.fillAllWith(exercise.defaultRestBetweenSets!);
          }
        } else {
          // For reps, pyramid, static modes - update the single rest input
          if (exercise.defaultRestBetweenSets != null && exercise.defaultRestBetweenSets! > 0) {
            _restInputKey.currentState?.setTotalSeconds(exercise.defaultRestBetweenSets!);
          }
        }
      });
    }
  }

  void _onModeChanged(ExerciseMode newMode) {
    setState(() {
      _mode = newMode;
      // Set appropriate defaults when switching modes
      if (_setsController.text.isEmpty) {
        _setsController.text = '4';
      }
      if (newMode == ExerciseMode.variableSets) {
        _setCount = int.tryParse(_setsController.text) ?? 4;
      }
    });
  }

  void _submit() async {
    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text) ?? 0;

    if (widget.showNameField && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter exercise name')),
      );
      return;
    }

    PlannedExercise result;

    // Get rest values
    final restBetweenSets = _restInputKey.currentState?.totalSeconds;
    final restPerSetValues = _perSetRestInputKey.currentState?.values;
    final restAfterExercise = widget.showRestAfterExercise
        ? _restAfterExerciseKey.currentState?.totalSeconds
        : null;

    switch (_mode) {
      case ExerciseMode.reps:
        final sets = int.tryParse(_setsController.text);
        final reps = int.tryParse(_repsController.text);
        if (sets == null || sets <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sets must be at least 1')),
          );
          return;
        }
        if (reps == null || reps <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reps must be at least 1')),
          );
          return;
        }
        result = PlannedExercise(
          exerciseName: name.isNotEmpty ? name : widget.exercise!.exerciseName,
          mode: _mode,
          targetSets: sets,
          targetReps: reps,
          targetWeight: weight,
          restBetweenSets: restBetweenSets != null && restBetweenSets > 0 ? restBetweenSets : null,
          restAfterExercise: restAfterExercise != null && restAfterExercise > 0 ? restAfterExercise : null,
        );
        break;

      case ExerciseMode.variableSets:
        final sets = int.tryParse(_setsController.text);
        if (sets == null || sets <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sets must be at least 1')),
          );
          return;
        }
        final repsValues = _repsInputKey.currentState?.values ?? [];
        if (repsValues.isEmpty || repsValues.first == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter reps for at least the first set')),
          );
          return;
        }
        // Build reps list, filling empty from previous
        final repsPerSet = <int>[];
        for (int i = 0; i < repsValues.length; i++) {
          final value = repsValues[i];
          if (value != null && value > 0) {
            repsPerSet.add(value);
          } else if (repsPerSet.isNotEmpty) {
            repsPerSet.add(repsPerSet.last);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter valid values for all sets')),
            );
            return;
          }
        }
        // Build rest per set list, filling empty from previous
        List<int>? restPerSet;
        if (restPerSetValues != null && restPerSetValues.isNotEmpty) {
          restPerSet = <int>[];
          for (int i = 0; i < restPerSetValues.length; i++) {
            final value = restPerSetValues[i];
            if (value != null && value > 0) {
              restPerSet.add(value);
            } else if (restPerSet.isNotEmpty) {
              restPerSet.add(restPerSet.last);
            } else {
              restPerSet.add(0); // No rest specified
            }
          }
          // Check if all zeros, then set to null
          if (restPerSet.every((r) => r == 0)) {
            restPerSet = null;
          }
        }
        result = PlannedExercise(
          exerciseName: name.isNotEmpty ? name : widget.exercise!.exerciseName,
          mode: _mode,
          targetSets: sets,
          targetRepsPerSet: repsPerSet,
          targetWeight: weight,
          restBetweenSetsPerSet: restPerSet,
          restAfterExercise: restAfterExercise != null && restAfterExercise > 0 ? restAfterExercise : null,
        );
        break;

      case ExerciseMode.pyramid:
        final pyramidTop = int.tryParse(_pyramidTopController.text);
        if (pyramidTop == null || pyramidTop <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pyramid top must be at least 1')),
          );
          return;
        }
        result = PlannedExercise(
          exerciseName: name.isNotEmpty ? name : widget.exercise!.exerciseName,
          mode: _mode,
          pyramidTop: pyramidTop,
          targetWeight: weight,
          restBetweenSets: restBetweenSets != null && restBetweenSets > 0 ? restBetweenSets : null,
          restAfterExercise: restAfterExercise != null && restAfterExercise > 0 ? restAfterExercise : null,
        );
        break;

      case ExerciseMode.static:
        final sets = int.tryParse(_setsController.text);
        final seconds = int.tryParse(_secondsController.text);
        if (sets == null || sets <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sets must be at least 1')),
          );
          return;
        }
        if (seconds == null || seconds <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seconds must be at least 1')),
          );
          return;
        }
        result = PlannedExercise(
          exerciseName: name.isNotEmpty ? name : widget.exercise!.exerciseName,
          mode: _mode,
          targetSets: sets,
          targetSeconds: seconds,
          targetWeight: weight,
          restBetweenSets: restBetweenSets != null && restBetweenSets > 0 ? restBetweenSets : null,
          restAfterExercise: restAfterExercise != null && restAfterExercise > 0 ? restAfterExercise : null,
        );
        break;
    }

    // Auto-add new exercise if enabled
    if (widget.autoAddNewExercises && name.isNotEmpty) {
      final existingExercise = await ExerciseStorage.findByName(name);
      if (existingExercise == null) {
        final newExercise = Exercise.create(
          name: name,
          mode: _mode,
          defaultSets: int.tryParse(_setsController.text) ?? 4,
          defaultReps: int.tryParse(_repsController.text) ?? 10,
          defaultPyramidTop: int.tryParse(_pyramidTopController.text) ?? 10,
          defaultSeconds: int.tryParse(_secondsController.text) ?? 30,
          defaultWeight: weight,
        );
        await ExerciseStorage.addExercise(newExercise);
      }
    }

    widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field with autocomplete
            if (widget.showNameField)
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

            if (widget.showNameField) const SizedBox(height: 16),

            // Mode selector
            const Text('Mode:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ModeChip(
                  label: 'Reps',
                  selected: _mode == ExerciseMode.reps,
                  onSelected: () => _onModeChanged(ExerciseMode.reps),
                ),
                _ModeChip(
                  label: 'Variable',
                  selected: _mode == ExerciseMode.variableSets,
                  onSelected: () => _onModeChanged(ExerciseMode.variableSets),
                ),
                _ModeChip(
                  label: 'Pyramid',
                  selected: _mode == ExerciseMode.pyramid,
                  onSelected: () => _onModeChanged(ExerciseMode.pyramid),
                ),
                _ModeChip(
                  label: 'Static',
                  selected: _mode == ExerciseMode.static,
                  onSelected: () => _onModeChanged(ExerciseMode.static),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode-specific fields
            _buildModeFields(),

            // Rest after exercise (for workouts)
            if (widget.showRestAfterExercise) ...[
              const SizedBox(height: 16),
              RestInput(
                key: _restAfterExerciseKey,
                initialSeconds: _initialRestAfterExercise,
                label: 'Rest after this exercise:',
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onDelete,
                  ),
                const Spacer(),
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

  Widget _buildModeFields() {
    switch (_mode) {
      case ExerciseMode.reps:
        return _buildRepsFields();
      case ExerciseMode.variableSets:
        return _buildVariableSetsFields();
      case ExerciseMode.pyramid:
        return _buildPyramidFields();
      case ExerciseMode.static:
        return _buildStaticFields();
    }
  }

  Widget _buildRepsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RestInput(
          key: _restInputKey,
          initialSeconds: _initialRestBetweenSets,
          label: 'Rest between sets:',
        ),
      ],
    );
  }

  Widget _buildVariableSetsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PerSetRepsInput(
          key: _repsInputKey,
          setCount: _setCount,
          initialValues: _initialRepsPerSet,
          label: 'Reps',
        ),
        const SizedBox(height: 12),
        PerSetRestInput(
          key: _perSetRestInputKey,
          setCount: _setCount,
          initialValues: _initialRestPerSet,
        ),
      ],
    );
  }

  Widget _buildPyramidFields() {
    final pyramidTop = int.tryParse(_pyramidTopController.text) ?? 0;
    final totalReps = pyramidTop > 0 ? pyramidTop * pyramidTop : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _pyramidTopController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Pyramid Top',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        if (pyramidTop > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Pattern: 1, 2, 3... $pyramidTop... 3, 2, 1 ($totalReps total reps)',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        RestInput(
          key: _restInputKey,
          initialSeconds: _initialRestBetweenSets,
          label: 'Rest between sets:',
        ),
      ],
    );
  }

  Widget _buildStaticFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _secondsController,
                keyboardType: TextInputType.number,
                inputFormatters: [NonNegativeIntFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Seconds',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RestInput(
          key: _restInputKey,
          initialSeconds: _initialRestBetweenSets,
          label: 'Rest between sets:',
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Compact card display for a planned exercise
class ExerciseCard extends StatelessWidget {
  final PlannedExercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onDelete,
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
                    Text(
                      exercise.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      exercise.displayString,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (exercise.restDisplayString.isNotEmpty)
                      Text(
                        'Rest: ${exercise.restDisplayString}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    if (exercise.restAfterExercise != null && exercise.restAfterExercise! > 0)
                      Text(
                        'Then rest: ${formatRestTime(exercise.restAfterExercise!)}',
                        style: TextStyle(color: Colors.blue[400], fontSize: 11),
                      ),
                  ],
                ),
              ),
              Chip(
                label: Text(exercise.modeLabel),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
