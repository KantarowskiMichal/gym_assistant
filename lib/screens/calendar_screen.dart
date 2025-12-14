import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_storage.dart';

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
    setState(() {
      _workoutTemplates = templates;
      _scheduledWorkouts = scheduled;
      _isLoading = false;
    });
  }

  List<Workout> _getWorkoutsForDate(DateTime date) {
    return _scheduledWorkouts.where((w) => w.occursOn(date)).toList();
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
        content: Text('Remove "${workout.name}" from calendar? This will not affect the workout template.'),
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

            final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
            final workouts = _getWorkoutsForDate(date);
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
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : workouts.isNotEmpty
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : null,
                  borderRadius: BorderRadius.circular(8),
                  border: workouts.isNotEmpty
                      ? Border.all(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        )
                      : null,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...workouts.take(2).map((w) => Icon(
                            w.icon,
                            size: 12,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          )),
                          if (workouts.length > 2)
                            Text(
                              '+${workouts.length - 2}',
                              style: TextStyle(
                                fontSize: 8,
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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

  Widget _buildWorkoutCard(Workout workout) {
    String recurrenceText;
    switch (workout.recurrenceType) {
      case RecurrenceType.oneOff:
        recurrenceText = 'One-time';
      case RecurrenceType.weekly:
        recurrenceText = 'Weekly';
      case RecurrenceType.offset:
        recurrenceText = 'Every ${workout.offsetDays} days';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    workout.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workout.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(recurrenceText),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeFromCalendar(workout),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove from calendar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${workout.exercises.length} exercise${workout.exercises.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (workout.exercises.isNotEmpty)
              Text(
                workout.exercises.map((e) => e.exerciseName).join(', '),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
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
