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
    if (exercise == null) return;

    _applyExerciseDefaults(exercise);
    Future.delayed(Duration.zero, () => _applyExerciseWidgetValues(exercise));
  }

  void _applyExerciseDefaults(Exercise exercise) {
    setState(() {
      _mode = exercise.mode;
      _setsController.text = exercise.defaultSets.toString();
      _repsController.text = exercise.defaultReps.toString();
      _pyramidTopController.text = exercise.defaultPyramidTop.toString();
      _secondsController.text = exercise.defaultSeconds.toString();
      _weightController.text = exercise.defaultWeight.toString();
      _setCount = exercise.defaultSets;
      _initialRepsPerSet = exercise.defaultRepsPerSet != null
          ? List<int>.from(exercise.defaultRepsPerSet!)
          : List.filled(exercise.defaultSets, exercise.defaultReps);
      _initialRestBetweenSets = exercise.defaultRestBetweenSets ?? 0;
      _initialRestPerSet = exercise.defaultRestBetweenSetsPerSet != null
          ? List<int>.from(exercise.defaultRestBetweenSetsPerSet!)
          : [];
      _initialRestAfterExercise = exercise.defaultRestAfterExercise ?? 0;
    });
  }

  void _applyExerciseWidgetValues(Exercise exercise) {
    _applyPerSetRepsValues(exercise);
    _applyRestValues(exercise);
    _applyRestAfterExerciseValue(exercise);
  }

  void _applyRestAfterExerciseValue(Exercise exercise) {
    final hasRestAfter = exercise.defaultRestAfterExercise != null &&
        exercise.defaultRestAfterExercise! > 0;
    if (hasRestAfter) {
      _restAfterExerciseKey.currentState?.setTotalSeconds(exercise.defaultRestAfterExercise!);
    }
  }

  void _applyPerSetRepsValues(Exercise exercise) {
    final hasPerSetReps = exercise.defaultRepsPerSet != null &&
        exercise.defaultRepsPerSet!.isNotEmpty;
    if (hasPerSetReps) {
      _repsInputKey.currentState?.setValues(exercise.defaultRepsPerSet!);
    } else {
      _repsInputKey.currentState?.fillAllWith(exercise.defaultReps);
    }
  }

  void _applyRestValues(Exercise exercise) {
    if (exercise.mode == ExerciseMode.variableSets) {
      _applyVariableSetsRestValues(exercise);
    } else {
      _applySingleRestValue(exercise);
    }
  }

  void _applyVariableSetsRestValues(Exercise exercise) {
    final hasPerSetRest = exercise.defaultRestBetweenSetsPerSet != null &&
        exercise.defaultRestBetweenSetsPerSet!.isNotEmpty;
    final hasSingleRest = exercise.defaultRestBetweenSets != null &&
        exercise.defaultRestBetweenSets! > 0;

    if (hasPerSetRest) {
      _perSetRestInputKey.currentState?.setValues(exercise.defaultRestBetweenSetsPerSet!);
    } else if (hasSingleRest) {
      _perSetRestInputKey.currentState?.fillAllWith(exercise.defaultRestBetweenSets!);
    }
  }

  void _applySingleRestValue(Exercise exercise) {
    final hasRest = exercise.defaultRestBetweenSets != null &&
        exercise.defaultRestBetweenSets! > 0;
    if (hasRest) {
      _restInputKey.currentState?.setTotalSeconds(exercise.defaultRestBetweenSets!);
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

    if (widget.showNameField && name.isEmpty) {
      _showError('Please enter exercise name');
      return;
    }

    final result = _buildPlannedExercise(name);
    if (result == null) return;

    await _autoAddExerciseIfNeeded(name);
    widget.onSave(result);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _getExerciseName(String name) {
    return name.isNotEmpty ? name : widget.exercise!.exerciseName;
  }

  int? _getRestAfterExercise() {
    if (!widget.showRestAfterExercise) return null;
    final value = _restAfterExerciseKey.currentState?.totalSeconds;
    return (value != null && value > 0) ? value : null;
  }

  int? _getRestBetweenSets() {
    final value = _restInputKey.currentState?.totalSeconds;
    return (value != null && value > 0) ? value : null;
  }

  PlannedExercise? _buildPlannedExercise(String name) {
    return switch (_mode) {
      ExerciseMode.reps => _buildRepsExercise(name),
      ExerciseMode.variableSets => _buildVariableSetsExercise(name),
      ExerciseMode.pyramid => _buildPyramidExercise(name),
      ExerciseMode.static => _buildStaticExercise(name),
    };
  }

  PlannedExercise? _buildRepsExercise(String name) {
    final sets = int.tryParse(_setsController.text);
    final reps = int.tryParse(_repsController.text);

    if (sets == null || sets <= 0) {
      _showError('Sets must be at least 1');
      return null;
    }
    if (reps == null || reps <= 0) {
      _showError('Reps must be at least 1');
      return null;
    }

    return PlannedExercise(
      exerciseName: _getExerciseName(name),
      mode: _mode,
      targetSets: sets,
      targetReps: reps,
      targetWeight: double.tryParse(_weightController.text) ?? 0,
      restBetweenSets: _getRestBetweenSets(),
      restAfterExercise: _getRestAfterExercise(),
    );
  }

  PlannedExercise? _buildVariableSetsExercise(String name) {
    final sets = int.tryParse(_setsController.text);
    if (sets == null || sets <= 0) {
      _showError('Sets must be at least 1');
      return null;
    }

    final repsPerSet = _buildRepsPerSetList();
    if (repsPerSet == null) return null;

    return PlannedExercise(
      exerciseName: _getExerciseName(name),
      mode: _mode,
      targetSets: sets,
      targetRepsPerSet: repsPerSet,
      targetWeight: double.tryParse(_weightController.text) ?? 0,
      restBetweenSetsPerSet: _buildRestPerSetList(),
      restAfterExercise: _getRestAfterExercise(),
    );
  }

  List<int>? _buildRepsPerSetList() {
    final repsValues = _repsInputKey.currentState?.values ?? [];
    if (repsValues.isEmpty || repsValues.first == null) {
      _showError('Please enter reps for at least the first set');
      return null;
    }

    final repsPerSet = <int>[];
    for (final value in repsValues) {
      if (value != null && value > 0) {
        repsPerSet.add(value);
      } else if (repsPerSet.isNotEmpty) {
        repsPerSet.add(repsPerSet.last);
      } else {
        _showError('Please enter valid values for all sets');
        return null;
      }
    }
    return repsPerSet;
  }

  List<int>? _buildRestPerSetList() {
    final restPerSetValues = _perSetRestInputKey.currentState?.values;
    if (restPerSetValues == null || restPerSetValues.isEmpty) return null;

    final restPerSet = <int>[];
    for (final value in restPerSetValues) {
      if (value != null && value > 0) {
        restPerSet.add(value);
      } else if (restPerSet.isNotEmpty) {
        restPerSet.add(restPerSet.last);
      } else {
        restPerSet.add(0);
      }
    }

    return restPerSet.every((r) => r == 0) ? null : restPerSet;
  }

  PlannedExercise? _buildPyramidExercise(String name) {
    final pyramidTop = int.tryParse(_pyramidTopController.text);
    if (pyramidTop == null || pyramidTop <= 0) {
      _showError('Pyramid top must be at least 1');
      return null;
    }

    return PlannedExercise(
      exerciseName: _getExerciseName(name),
      mode: _mode,
      pyramidTop: pyramidTop,
      targetWeight: double.tryParse(_weightController.text) ?? 0,
      restBetweenSets: _getRestBetweenSets(),
      restAfterExercise: _getRestAfterExercise(),
    );
  }

  PlannedExercise? _buildStaticExercise(String name) {
    final sets = int.tryParse(_setsController.text);
    final seconds = int.tryParse(_secondsController.text);

    if (sets == null || sets <= 0) {
      _showError('Sets must be at least 1');
      return null;
    }
    if (seconds == null || seconds <= 0) {
      _showError('Seconds must be at least 1');
      return null;
    }

    return PlannedExercise(
      exerciseName: _getExerciseName(name),
      mode: _mode,
      targetSets: sets,
      targetSeconds: seconds,
      targetWeight: double.tryParse(_weightController.text) ?? 0,
      restBetweenSets: _getRestBetweenSets(),
      restAfterExercise: _getRestAfterExercise(),
    );
  }

  Future<void> _autoAddExerciseIfNeeded(String name) async {
    if (!widget.autoAddNewExercises || name.isEmpty) return;

    final existingExercise = await ExerciseStorage.findByName(name);
    if (existingExercise != null) return;

    final newExercise = Exercise.create(
      name: name,
      mode: _mode,
      defaultSets: int.tryParse(_setsController.text) ?? 4,
      defaultReps: int.tryParse(_repsController.text) ?? 10,
      defaultPyramidTop: int.tryParse(_pyramidTopController.text) ?? 10,
      defaultSeconds: int.tryParse(_secondsController.text) ?? 30,
      defaultWeight: double.tryParse(_weightController.text) ?? 0,
    );
    await ExerciseStorage.addExercise(newExercise);
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
              Expanded(child: _buildExerciseInfo()),
              _buildModeChip(),
              if (onDelete != null) _buildDeleteButton(),
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
      label: Text(exercise.modeLabel),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
      onPressed: onDelete,
      visualDensity: VisualDensity.compact,
    );
  }
}
