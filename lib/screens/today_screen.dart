import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../models/completed_workout.dart';
import '../services/workout_storage.dart';
import '../services/completed_workout_storage.dart';
import '../widgets/complete_workout_dialog.dart';
import '../widgets/completion_checkbox.dart';
import '../widgets/completion_options_dialog.dart';
import '../widgets/workout_icon_container.dart';
import 'workouts_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Workout> _todayWorkouts = [];
  Map<String, CompletedWorkout> _completedMap = {};
  bool _isLoading = true;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final scheduled = await WorkoutStorage.getScheduledForDate(_today);
    final completed = await CompletedWorkoutStorage.getCompletedForDate(_today);

    // Build a map of scheduledWorkoutId -> CompletedWorkout for quick lookup
    final completedMap = <String, CompletedWorkout>{};
    for (final c in completed) {
      completedMap[c.scheduledWorkoutId] = c;
    }

    setState(() {
      _todayWorkouts = scheduled;
      _completedMap = completedMap;
      _isLoading = false;
    });
  }

  bool _isCompleted(Workout workout) {
    return _completedMap.containsKey(workout.id);
  }

  CompletedWorkout? _getCompleted(Workout workout) {
    return _completedMap[workout.id];
  }

  Future<void> _openCompleteDialog(Workout workout) async {
    final existingCompleted = _getCompleted(workout);

    final result = await showDialog<CompletedWorkout>(
      context: context,
      builder: (context) => CompleteWorkoutDialog(
        workout: workout,
        scheduledDate: _today,
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

  Future<void> _toggleCompletion(Workout workout) async {
    final existingCompleted = _getCompleted(workout);

    if (existingCompleted != null) {
      // Uncomplete - delete the completion record
      await CompletedWorkoutStorage.deleteCompleted(existingCompleted.id);
      _loadData();
    } else {
      // Prompt user: do you want to make changes?
      final wantChanges = await showCompletionOptionsDialog(context);

      if (wantChanges == true) {
        _openCompleteDialog(workout);
      } else if (wantChanges == false) {
        // Complete immediately without changes
        final completed = CompletedWorkout.fromWorkout(workout, _today);
        await CompletedWorkoutStorage.addCompleted(completed);
        _loadData();
      }
    }
  }

  String get _formattedDate {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[_today.weekday - 1]}, ${months[_today.month - 1]} ${_today.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today'),
        Text(
          _formattedDate,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_todayWorkouts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildWorkoutList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts scheduled for today',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule workouts in the Calendar tab',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayWorkouts.length,
      itemBuilder: (context, index) {
        final workout = _todayWorkouts[index];
        return _buildWorkoutCard(workout);
      },
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final isCompleted = _isCompleted(workout);
    final completed = _getCompleted(workout);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _getCardColor(isCompleted),
      child: InkWell(
        onTap: () => _editWorkout(workout),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildCompletionCheckbox(workout, isCompleted),
              const SizedBox(width: 12),
              _buildWorkoutIcon(workout, isCompleted),
              const SizedBox(width: 16),
              Expanded(child: _buildWorkoutInfo(workout, isCompleted, completed)),
              _buildTrailingWidget(workout, isCompleted),
            ],
          ),
        ),
      ),
    );
  }

  Color? _getCardColor(bool isCompleted) {
    return isCompleted
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
  }

  Widget _buildCompletionCheckbox(Workout workout, bool isCompleted) {
    return CompletionCheckbox(
      isCompleted: isCompleted,
      onTap: () => _toggleCompletion(workout),
    );
  }

  Widget _buildWorkoutIcon(Workout workout, bool isCompleted) {
    return WorkoutIconContainer(
      icon: workout.icon,
      isCompleted: isCompleted,
    );
  }

  Widget _buildWorkoutInfo(
    Workout workout,
    bool isCompleted,
    CompletedWorkout? completed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkoutName(workout, isCompleted),
        const SizedBox(height: 4),
        _buildExerciseCount(workout, isCompleted, completed),
        if (workout.exercises.isNotEmpty)
          _buildExerciseList(workout, isCompleted, completed),
      ],
    );
  }

  Widget _buildWorkoutName(Workout workout, bool isCompleted) {
    return Text(
      workout.name,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        decoration: isCompleted ? TextDecoration.lineThrough : null,
        color: isCompleted ? Colors.grey[600] : null,
      ),
    );
  }

  Widget _buildExerciseCount(
    Workout workout,
    bool isCompleted,
    CompletedWorkout? completed,
  ) {
    final count = isCompleted ? completed!.exercises.length : workout.exercises.length;
    return Text(
      '$count exercise${count != 1 ? 's' : ''}',
      style: TextStyle(color: Colors.grey[600]),
    );
  }

  Widget _buildExerciseList(
    Workout workout,
    bool isCompleted,
    CompletedWorkout? completed,
  ) {
    final exercises = isCompleted ? completed!.exercises : workout.exercises;
    return Text(
      exercises.map((e) => e.exerciseName).join(', '),
      style: TextStyle(color: Colors.grey[500], fontSize: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailingWidget(Workout workout, bool isCompleted) {
    if (isCompleted) {
      return IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _openCompleteDialog(workout),
        tooltip: 'Edit completed workout',
      );
    }

    return Icon(Icons.chevron_right, color: Colors.grey[400]);
  }
}
