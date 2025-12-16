/// Exercise mode defining how an exercise is measured
enum ExerciseMode {
  reps,         // Standard: sets × reps
  variableSets, // Per-set: sets with individual rep counts
  pyramid,      // Pyramid: 1,2,3...top...3,2,1
  static,       // Time-based: sets × seconds
}

/// Represents an exercise definition with default values
class Exercise {
  final String id;
  final String name;
  final ExerciseMode mode;
  final int defaultSets;           // For reps, variableSets, static
  final int defaultReps;           // For reps mode
  final List<int>? defaultRepsPerSet; // For variableSets mode
  final int defaultPyramidTop;     // For pyramid mode
  final int defaultSeconds;        // For static mode
  final double defaultWeight;
  final int? defaultRestBetweenSets;        // Rest in seconds (for reps, pyramid, static)
  final List<int>? defaultRestBetweenSetsPerSet; // Rest per set in seconds (for variableSets)

  const Exercise({
    required this.id,
    required this.name,
    required this.mode,
    this.defaultSets = 4,
    this.defaultReps = 10,
    this.defaultRepsPerSet,
    this.defaultPyramidTop = 10,
    this.defaultSeconds = 30,
    this.defaultWeight = 0,
    this.defaultRestBetweenSets,
    this.defaultRestBetweenSetsPerSet,
  });

  /// Hardcoded default exercises
  static const List<Exercise> defaults = [
    // Reps mode exercises
    Exercise(id: 'default_pull_ups', name: 'Pull Ups', mode: ExerciseMode.reps),
    Exercise(id: 'default_push_ups', name: 'Push Ups', mode: ExerciseMode.reps),
    Exercise(id: 'default_dips', name: 'Dips', mode: ExerciseMode.reps),
    Exercise(id: 'default_leg_press', name: 'Leg Press', mode: ExerciseMode.reps),
    Exercise(id: 'default_bench_press', name: 'Bench Press', mode: ExerciseMode.reps),
    Exercise(id: 'default_dead_lift', name: 'Dead Lift', mode: ExerciseMode.reps),
    // Static mode exercises
    Exercise(id: 'default_planche', name: 'Planche', mode: ExerciseMode.static),
    Exercise(id: 'default_dead_hang', name: 'Dead Hang', mode: ExerciseMode.static),
    Exercise(id: 'default_front_lever', name: 'Front Lever', mode: ExerciseMode.static),
    Exercise(id: 'default_back_lever', name: 'Back Lever', mode: ExerciseMode.static),
  ];

  factory Exercise.create({
    required String name,
    required ExerciseMode mode,
    int defaultSets = 4,
    int defaultReps = 10,
    List<int>? defaultRepsPerSet,
    int defaultPyramidTop = 10,
    int defaultSeconds = 30,
    double defaultWeight = 0,
    int? defaultRestBetweenSets,
    List<int>? defaultRestBetweenSetsPerSet,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mode: mode,
      defaultSets: defaultSets,
      defaultReps: defaultReps,
      defaultRepsPerSet: defaultRepsPerSet,
      defaultPyramidTop: defaultPyramidTop,
      defaultSeconds: defaultSeconds,
      defaultWeight: defaultWeight,
      defaultRestBetweenSets: defaultRestBetweenSets,
      defaultRestBetweenSetsPerSet: defaultRestBetweenSetsPerSet,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode.name,
    'defaultSets': defaultSets,
    'defaultReps': defaultReps,
    'defaultRepsPerSet': defaultRepsPerSet,
    'defaultPyramidTop': defaultPyramidTop,
    'defaultSeconds': defaultSeconds,
    'defaultWeight': defaultWeight,
    'defaultRestBetweenSets': defaultRestBetweenSets,
    'defaultRestBetweenSetsPerSet': defaultRestBetweenSetsPerSet,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: ExerciseMode.values.firstWhere((e) => e.name == json['mode']),
      defaultSets: json['defaultSets'] as int? ?? 4,
      defaultReps: json['defaultReps'] as int? ?? 10,
      defaultRepsPerSet: (json['defaultRepsPerSet'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      defaultPyramidTop: json['defaultPyramidTop'] as int? ?? 10,
      defaultSeconds: json['defaultSeconds'] as int? ?? 30,
      defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? 0,
      defaultRestBetweenSets: json['defaultRestBetweenSets'] as int?,
      defaultRestBetweenSetsPerSet: (json['defaultRestBetweenSetsPerSet'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Exercise copyWith({
    String? name,
    ExerciseMode? mode,
    int? defaultSets,
    int? defaultReps,
    List<int>? defaultRepsPerSet,
    int? defaultPyramidTop,
    int? defaultSeconds,
    double? defaultWeight,
    int? defaultRestBetweenSets,
    List<int>? defaultRestBetweenSetsPerSet,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultRepsPerSet: defaultRepsPerSet ?? this.defaultRepsPerSet,
      defaultPyramidTop: defaultPyramidTop ?? this.defaultPyramidTop,
      defaultSeconds: defaultSeconds ?? this.defaultSeconds,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      defaultRestBetweenSets: defaultRestBetweenSets ?? this.defaultRestBetweenSets,
      defaultRestBetweenSetsPerSet: defaultRestBetweenSetsPerSet ?? this.defaultRestBetweenSetsPerSet,
    );
  }

  /// Get mode-appropriate display label
  String get modeLabel {
    switch (mode) {
      case ExerciseMode.reps:
        return 'Reps';
      case ExerciseMode.variableSets:
        return 'Variable';
      case ExerciseMode.pyramid:
        return 'Pyramid';
      case ExerciseMode.static:
        return 'Static';
    }
  }

  /// Get a summary string for this exercise's defaults
  String get defaultsSummary {
    switch (mode) {
      case ExerciseMode.reps:
        return '$defaultSets × $defaultReps reps';
      case ExerciseMode.variableSets:
        if (defaultRepsPerSet != null && defaultRepsPerSet!.isNotEmpty) {
          return '$defaultSets sets (${defaultRepsPerSet!.join(', ')})';
        }
        return '$defaultSets sets (variable)';
      case ExerciseMode.pyramid:
        return 'Pyramid to $defaultPyramidTop';
      case ExerciseMode.static:
        return '$defaultSets × ${defaultSeconds}s';
    }
  }

  /// Check if this is a user-defined exercise (not a default)
  bool get isCustom => !id.startsWith('default_');
}
