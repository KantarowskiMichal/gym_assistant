/// Represents the type of exercise
/// - dynamic: counted in reps (push ups, pull ups, etc.)
/// - static: measured in duration/seconds (planks, hangs, etc.)
enum ExerciseType { dynamic, static }

/// Represents an exercise definition with default values
class Exercise {
  final String id;
  final String name;
  final ExerciseType type;
  final int defaultSets;
  final int defaultRepsOrDuration; // reps for dynamic, seconds for static
  final double defaultWeight;

  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    this.defaultSets = 4,
    this.defaultRepsOrDuration = 10, // Will be 30 for static in predefined
    this.defaultWeight = 0,
  });

  /// Hardcoded default exercises - can be overridden by user-defined ones
  static const List<Exercise> defaults = [
    Exercise(id: 'default_pull_ups', name: 'Pull Ups', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_push_ups', name: 'Push Ups', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_dips', name: 'Dips', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_leg_press', name: 'Leg Press', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_planche', name: 'Planche', type: ExerciseType.static, defaultSets: 4, defaultRepsOrDuration: 30),
    Exercise(id: 'default_bench_press', name: 'Bench Press', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_dead_lift', name: 'Dead Lift', type: ExerciseType.dynamic, defaultSets: 4, defaultRepsOrDuration: 10),
    Exercise(id: 'default_dead_hang', name: 'Dead Hang', type: ExerciseType.static, defaultSets: 4, defaultRepsOrDuration: 30),
    Exercise(id: 'default_front_lever', name: 'Front Lever', type: ExerciseType.static, defaultSets: 4, defaultRepsOrDuration: 30),
    Exercise(id: 'default_back_lever', name: 'Back Lever', type: ExerciseType.static, defaultSets: 4, defaultRepsOrDuration: 30),
  ];

  factory Exercise.create({
    required String name,
    required ExerciseType type,
    int defaultSets = 4,
    int? defaultRepsOrDuration,
    double defaultWeight = 0,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      defaultSets: defaultSets,
      defaultRepsOrDuration: defaultRepsOrDuration ?? (type == ExerciseType.static ? 30 : 10),
      defaultWeight: defaultWeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'defaultSets': defaultSets,
    'defaultRepsOrDuration': defaultRepsOrDuration,
    'defaultWeight': defaultWeight,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ExerciseType.values.firstWhere((e) => e.name == json['type']),
      defaultSets: json['defaultSets'] as int? ?? 4,
      defaultRepsOrDuration: json['defaultRepsOrDuration'] as int? ?? 10,
      defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? 0,
    );
  }

  Exercise copyWith({
    String? name,
    ExerciseType? type,
    int? defaultSets,
    int? defaultRepsOrDuration,
    double? defaultWeight,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultRepsOrDuration: defaultRepsOrDuration ?? this.defaultRepsOrDuration,
      defaultWeight: defaultWeight ?? this.defaultWeight,
    );
  }

  String get repsOrDurationLabel =>
      type == ExerciseType.dynamic ? 'reps' : 'seconds';

  /// Check if this is a user-defined exercise (not a default)
  bool get isCustom => !id.startsWith('default_');
}
