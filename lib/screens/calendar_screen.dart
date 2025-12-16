import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/completed_workout.dart';
import '../services/workout_storage.dart';
import '../services/completed_workout_storage.dart';
import '../utils/input_formatters.dart';
import '../widgets/complete_workout_dialog.dart';
import 'workouts_screen.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Workout> _scheduledWorkouts = [];
  List<Workout> _workoutTemplates = [];
  List<CompletedWorkout> _completedWorkouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Migrate old data if needed
    await WorkoutStorage.migrateIfNeeded();

    // Load templates (for picker) and scheduled (for calendar) separately
    final templates = await WorkoutStorage.loadTemplates();
    final scheduled = await WorkoutStorage.loadScheduled();
    final completed = await CompletedWorkoutStorage.loadAll();
    setState(() {
      _workoutTemplates = templates;
      _scheduledWorkouts = scheduled;
      _completedWorkouts = completed;
      _isLoading = false;
    });
  }

  List<Workout> _getWorkoutsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final scheduled = _scheduledWorkouts.where((w) => w.occursOn(date)).toList();

    // Also include orphaned completed workouts (where scheduled workout was deleted)
    final orphanedCompleted = _completedWorkouts.where((c) {
      // Check if this completed workout is for this date
      final sameDate = c.scheduledDate.year == normalizedDate.year &&
          c.scheduledDate.month == normalizedDate.month &&
          c.scheduledDate.day == normalizedDate.day;
      if (!sameDate) return false;

      // Check if the scheduled workout still exists
      final hasScheduled = scheduled.any((w) => w.id == c.scheduledWorkoutId);
      return !hasScheduled;
    }).toList();

    // Convert orphaned completed workouts to virtual Workout objects for display
    for (final completed in orphanedCompleted) {
      scheduled.add(Workout(
        id: completed.scheduledWorkoutId, // Use original ID for lookups
        name: completed.workoutName,
        iconCodePoint: completed.iconCodePoint,
        exercises: completed.exercises,
        startDate: completed.scheduledDate,
        recurrenceType: RecurrenceType.oneOff, // Orphaned workouts don't recur
        offsetDays: null,
      ));
    }

    return scheduled;
  }

  bool _isCompletedForDate(Workout workout, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _completedWorkouts.any((c) =>
        c.scheduledWorkoutId == workout.id &&
        c.scheduledDate.year == normalizedDate.year &&
        c.scheduledDate.month == normalizedDate.month &&
        c.scheduledDate.day == normalizedDate.day);
  }

  CompletedWorkout? _getCompletedForDate(Workout workout, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    try {
      return _completedWorkouts.firstWhere((c) =>
          c.scheduledWorkoutId == workout.id &&
          c.scheduledDate.year == normalizedDate.year &&
          c.scheduledDate.month == normalizedDate.month &&
          c.scheduledDate.day == normalizedDate.day);
    } catch (_) {
      return null;
    }
  }

  bool _hasAnyCompletedForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _completedWorkouts.any((c) =>
        c.scheduledDate.year == normalizedDate.year &&
        c.scheduledDate.month == normalizedDate.month &&
        c.scheduledDate.day == normalizedDate.day);
  }

  Future<void> _openCompleteDialog(Workout workout, DateTime date) async {
    final existingCompleted = _getCompletedForDate(workout, date);

    final result = await showDialog<CompletedWorkout>(
      context: context,
      builder: (context) => CompleteWorkoutDialog(
        workout: workout,
        scheduledDate: date,
        existingCompleted: existingCompleted,
      ),
    );

    if (result != null) {
      if (existingCompleted != null) {
        await CompletedWorkoutStorage.updateCompleted(result);
      } else {
        await CompletedWorkoutStorage.addCompleted(result);
      }
      _loadData();
    }
  }

  Future<void> _editWorkout(Workout workout) async {
    final originalName = workout.name;

    final result = await Navigator.push<Workout>(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutTemplateEditor(existingWorkout: workout),
      ),
    );

    if (result != null) {
      await WorkoutStorage.updateTemplateAndScheduled(result, originalName);
      _loadData();
    }
  }

  Future<void> _toggleCompletion(Workout workout, DateTime date) async {
    final existingCompleted = _getCompletedForDate(workout, date);

    if (existingCompleted != null) {
      // Check if this is an orphaned workout (no template exists)
      final isOrphaned = _isOrphanedWorkout(workout);

      if (isOrphaned) {
        // Warn user that uncompleting will delete the workout record
        final confirm = await _showOrphanedUncompleteWarning(workout);
        if (confirm != true) return;
      }

      // Uncomplete - delete the completion record
      await CompletedWorkoutStorage.deleteCompleted(existingCompleted.id);
      _loadData();
    } else {
      // Prompt user: do you want to make changes?
      final wantChanges = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Workout'),
          content: const Text('Do you want to modify the workout before completing?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (wantChanges == true) {
        _openCompleteDialog(workout, date);
      } else if (wantChanges == false) {
        // Complete immediately without changes
        final completed = CompletedWorkout.fromWorkout(workout, date);
        await CompletedWorkoutStorage.addCompleted(completed);
        _loadData();
      }
    }
  }

  Future<bool?> _showOrphanedUncompleteWarning(Workout workout) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout Record?'),
        content: Text(
          'The workout template "${workout.name}" no longer exists. '
          'Unmarking this as completed will permanently delete this workout record.',
        ),
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
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _scheduleWorkout() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    if (_workoutTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a workout first in the Workouts tab')),
      );
      return;
    }

    // Show dialog to pick workout and recurrence
    final result = await showDialog<_ScheduleResult>(
      context: context,
      builder: (context) => _ScheduleWorkoutDialog(
        workouts: _workoutTemplates,
        selectedDate: _selectedDate!,
      ),
    );

    if (result != null) {
      // Create a scheduled copy of the workout template
      final scheduledWorkout = Workout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.workout.name,
        iconCodePoint: result.workout.iconCodePoint,
        exercises: result.workout.exercises,
        startDate: _selectedDate!,
        recurrenceType: result.recurrenceType,
        offsetDays: result.offsetDays,
      );

      await WorkoutStorage.addScheduled(scheduledWorkout);
      _loadData();
    }
  }

  Future<void> _removeFromCalendar(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Calendar'),
        content: Text('Remove "${workout.name}" from calendar? This will not affect the workout template or completed records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WorkoutStorage.deleteScheduled(workout.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendarHeader(),
                _buildCalendarGrid(),
                const Divider(),
                Expanded(child: _buildSelectedDayWorkouts()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scheduleWorkout,
        tooltip: 'Schedule Workout',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          Text(
            '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        Row(
          children: dayLabels.map((day) => Expanded(
            child: Center(
              child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayOffset = index - (startingWeekday - 1);
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const SizedBox();
            }
            return _buildCalendarDayCell(dayOffset);
          },
        ),
      ],
    );
  }

  Widget _buildCalendarDayCell(int dayOffset) {
    final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
    final workouts = _getWorkoutsForDate(date);
    final hasCompleted = _hasAnyCompletedForDate(date);
    final allCompleted = workouts.isNotEmpty &&
        workouts.every((w) => _isCompletedForDate(w, date));
    final isSelected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return GestureDetector(
      onTap: () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getDayCellColor(isSelected, allCompleted, isToday, workouts.isNotEmpty),
          borderRadius: BorderRadius.circular(8),
          border: _getDayCellBorder(isSelected, allCompleted, workouts.isNotEmpty),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${dayOffset + 1}',
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isToday ? FontWeight.bold : null,
                fontSize: 12,
              ),
            ),
            if (workouts.isNotEmpty)
              _buildDayCellWorkoutIcons(
                workouts: workouts,
                date: date,
                isSelected: isSelected,
                allCompleted: allCompleted,
                hasCompleted: hasCompleted,
              ),
          ],
        ),
      ),
    );
  }

  Color? _getDayCellColor(bool isSelected, bool allCompleted, bool isToday, bool hasWorkouts) {
    if (isSelected) return Theme.of(context).colorScheme.primary;
    if (allCompleted) return Colors.green.withValues(alpha: 0.2);
    if (isToday) return Theme.of(context).colorScheme.primaryContainer;
    if (hasWorkouts) return Theme.of(context).colorScheme.surfaceContainerHighest;
    return null;
  }

  Border? _getDayCellBorder(bool isSelected, bool allCompleted, bool hasWorkouts) {
    if (!hasWorkouts) return null;

    Color borderColor;
    if (isSelected) {
      borderColor = Colors.white;
    } else if (allCompleted) {
      borderColor = Colors.green;
    } else {
      borderColor = Theme.of(context).colorScheme.primary;
    }
    return Border.all(color: borderColor, width: 1.5);
  }

  Widget _buildDayCellWorkoutIcons({
    required List<Workout> workouts,
    required DateTime date,
    required bool isSelected,
    required bool allCompleted,
    required bool hasCompleted,
  }) {
    if (allCompleted) {
      return Icon(
        Icons.check,
        size: 12,
        color: isSelected ? Colors.white : Colors.green,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...workouts.take(2).map((w) => _buildWorkoutIcon(w, date, isSelected)),
        if (workouts.length > 2)
          Text(
            '+${workouts.length - 2}',
            style: TextStyle(
              fontSize: 8,
              color: _getWorkoutIconColor(isSelected, hasCompleted),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkoutIcon(Workout workout, DateTime date, bool isSelected) {
    final isWorkoutCompleted = _isCompletedForDate(workout, date);
    return Icon(
      isWorkoutCompleted ? Icons.check_circle : workout.icon,
      size: 12,
      color: _getWorkoutIconColor(isSelected, isWorkoutCompleted),
    );
  }

  Color _getWorkoutIconColor(bool isSelected, bool isCompleted) {
    if (isSelected) return Colors.white;
    if (isCompleted) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildSelectedDayWorkouts() {
    if (_selectedDate == null) {
      return const Center(
        child: Text('Select a day to see workouts'),
      );
    }

    final workouts = _getWorkoutsForDate(_selectedDate!);
    final dateStr = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    if (workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No workouts on $dateStr'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _scheduleWorkout,
              icon: const Icon(Icons.add),
              label: const Text('Schedule Workout'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return _buildWorkoutCard(workout);
      },
    );
  }

  /// Check if a workout is orphaned (only exists because of completed records)
  bool _isOrphanedWorkout(Workout workout) {
    return !_scheduledWorkouts.any((w) => w.id == workout.id);
  }

  Widget _buildWorkoutCard(Workout workout) {
    final isCompleted = _isCompletedForDate(workout, _selectedDate!);
    final completed = _getCompletedForDate(workout, _selectedDate!);
    final isOrphaned = _isOrphanedWorkout(workout);
    final recurrenceText = _getRecurrenceText(workout, isOrphaned);
    final exercises = isCompleted ? completed!.exercises : workout.exercises;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCompleted
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: isOrphaned
            ? () => _openCompleteDialog(workout, _selectedDate!)
            : () => _editWorkout(workout),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWorkoutCardHeader(workout, isCompleted, recurrenceText),
              const SizedBox(height: 8),
              _buildExerciseCountText(exercises.length),
              if (exercises.isNotEmpty)
                _buildExerciseNamesText(exercises),
              if (isCompleted)
                _buildCompletedBadge(),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecurrenceText(Workout workout, bool isOrphaned) {
    if (isOrphaned) return 'Completed';
    return switch (workout.recurrenceType) {
      RecurrenceType.oneOff => 'One-time',
      RecurrenceType.weekly => 'Weekly',
      RecurrenceType.offset => 'Every ${workout.offsetDays} days',
    };
  }

  Widget _buildWorkoutCardHeader(Workout workout, bool isCompleted, String recurrenceText) {
    return Row(
      children: [
        _buildCompletionCheckbox(workout, isCompleted),
        const SizedBox(width: 12),
        _buildWorkoutIconBox(workout, isCompleted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            workout.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey[600] : null,
            ),
          ),
        ),
        Chip(
          label: Text(recurrenceText),
          visualDensity: VisualDensity.compact,
        ),
        _buildCardActionButton(workout, isCompleted),
      ],
    );
  }

  Widget _buildCompletionCheckbox(Workout workout, bool isCompleted) {
    return GestureDetector(
      onTap: () => _toggleCompletion(workout, _selectedDate!),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? Colors.green
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: isCompleted
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
        ),
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildWorkoutIconBox(Workout workout, bool isCompleted) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        workout.icon,
        color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildCardActionButton(Workout workout, bool isCompleted) {
    if (isCompleted) {
      return IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _openCompleteDialog(workout, _selectedDate!),
        visualDensity: VisualDensity.compact,
        tooltip: 'Edit completed workout',
      );
    }
    return IconButton(
      icon: const Icon(Icons.close, color: Colors.red),
      onPressed: () => _removeFromCalendar(workout),
      visualDensity: VisualDensity.compact,
      tooltip: 'Remove from calendar',
    );
  }

  Widget _buildExerciseCountText(int count) {
    final plural = count != 1 ? 's' : '';
    return Text(
      '$count exercise$plural',
      style: TextStyle(color: Colors.grey[600]),
    );
  }

  Widget _buildExerciseNamesText(List<PlannedExercise> exercises) {
    return Text(
      exercises.map((e) => e.exerciseName).join(', '),
      style: TextStyle(color: Colors.grey[500], fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCompletedBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleResult {
  final Workout workout;
  final RecurrenceType recurrenceType;
  final int? offsetDays;

  _ScheduleResult({
    required this.workout,
    required this.recurrenceType,
    this.offsetDays,
  });
}

class _ScheduleWorkoutDialog extends StatefulWidget {
  final List<Workout> workouts;
  final DateTime selectedDate;

  const _ScheduleWorkoutDialog({
    required this.workouts,
    required this.selectedDate,
  });

  @override
  State<_ScheduleWorkoutDialog> createState() => _ScheduleWorkoutDialogState();
}

class _ScheduleWorkoutDialogState extends State<_ScheduleWorkoutDialog> {
  Workout? _selectedWorkout;
  RecurrenceType _recurrenceType = RecurrenceType.oneOff;
  final _offsetController = TextEditingController(text: '1');
  bool _offsetTouched = false;

  @override
  void dispose() {
    _offsetController.dispose();
    super.dispose();
  }

  void _onOffsetTap() {
    if (!_offsetTouched) {
      _offsetController.clear();
      _offsetTouched = true;
    }
  }

  void _submit() {
    if (_selectedWorkout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workout')),
      );
      return;
    }

    int? offsetDays;
    if (_recurrenceType == RecurrenceType.offset) {
      offsetDays = int.tryParse(_offsetController.text);
      if (offsetDays == null || offsetDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid days')),
        );
        return;
      }
    }

    Navigator.pop(context, _ScheduleResult(
      workout: _selectedWorkout!,
      recurrenceType: _recurrenceType,
      offsetDays: offsetDays,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}';

    return AlertDialog(
      title: Text('Schedule for $dateStr'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Workout:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...widget.workouts.map((workout) {
              final isSelected = _selectedWorkout?.id == workout.id;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Row(
                  children: [
                    Icon(workout.icon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(workout.name)),
                  ],
                ),
                subtitle: Text('${workout.exercises.length} exercises'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => setState(() => _selectedWorkout = workout),
              );
            }),
            const SizedBox(height: 16),
            const Text('Recurrence:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('One-off'),
                  selected: _recurrenceType == RecurrenceType.oneOff,
                  onSelected: (s) {
                    if (s) setState(() => _recurrenceType = RecurrenceType.oneOff);
                  },
                ),
                ChoiceChip(
                  label: const Text('Weekly'),
                  selected: _recurrenceType == RecurrenceType.weekly,
                  onSelected: (s) {
                    if (s) setState(() => _recurrenceType = RecurrenceType.weekly);
                  },
                ),
                ChoiceChip(
                  label: const Text('Every X days'),
                  selected: _recurrenceType == RecurrenceType.offset,
                  onSelected: (s) {
                    if (s) setState(() => _recurrenceType = RecurrenceType.offset);
                  },
                ),
              ],
            ),
            if (_recurrenceType == RecurrenceType.offset) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Repeat every '),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _offsetController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [NonNegativeIntFormatter()],
                      textAlign: TextAlign.center,
                      onTap: _onOffsetTap,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  const Text(' days'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Schedule'),
        ),
      ],
    );
  }
}
