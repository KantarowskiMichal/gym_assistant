import 'dart:convert';
import 'package:drift/drift.dart';

/// Exercise type: static (measured in seconds) or dynamic (measured in reps)
enum ExerciseType {
  static,
  dynamic,
}

/// Exercise mode: determines flow and UI
enum ExerciseMode {
  reps,
  variableSets,
  pyramid,
}

/// Recurrence type for schedules
enum RecurrenceType {
  oneOff,
  weekly,
  offset,
}

/// Represents a single set within an exercise
class ExerciseSet {
  final int value; // reps or seconds
  final double weight; // kg
  final int? rest; // seconds, nullable

  const ExerciseSet({
    required this.value,
    required this.weight,
    this.rest,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'weight': weight,
        'rest': rest,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    final restValue = json['rest'] as int?;
    return ExerciseSet(
      value: json['value'] as int,
      weight: (json['weight'] as num).toDouble(),
      // Store 0 as null
      rest: (restValue == null || restValue == 0) ? null : restValue,
    );
  }

  ExerciseSet copyWith({
    int? value,
    double? weight,
    int? rest,
  }) {
    return ExerciseSet(
      value: value ?? this.value,
      weight: weight ?? this.weight,
      rest: rest ?? this.rest,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSet &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          weight == other.weight &&
          rest == other.rest;

  @override
  int get hashCode => value.hashCode ^ weight.hashCode ^ rest.hashCode;
}

/// Type converter for ExerciseType enum
class ExerciseTypeConverter extends TypeConverter<ExerciseType, String> {
  const ExerciseTypeConverter();

  @override
  ExerciseType fromSql(String fromDb) {
    return ExerciseType.values.firstWhere((e) => e.name == fromDb);
  }

  @override
  String toSql(ExerciseType value) {
    return value.name;
  }
}

/// Type converter for ExerciseMode enum
class ExerciseModeConverter extends TypeConverter<ExerciseMode, String> {
  const ExerciseModeConverter();

  @override
  ExerciseMode fromSql(String fromDb) {
    return ExerciseMode.values.firstWhere((e) => e.name == fromDb);
  }

  @override
  String toSql(ExerciseMode value) {
    return value.name;
  }
}

/// Type converter for RecurrenceType enum
class RecurrenceTypeConverter extends TypeConverter<RecurrenceType, String> {
  const RecurrenceTypeConverter();

  @override
  RecurrenceType fromSql(String fromDb) {
    return RecurrenceType.values.firstWhere((e) => e.name == fromDb);
  }

  @override
  String toSql(RecurrenceType value) {
    return value.name;
  }
}

/// Type converter for [List] of [ExerciseSet] stored as JSON
class ExerciseSetsConverter extends TypeConverter<List<ExerciseSet>, String> {
  const ExerciseSetsConverter();

  @override
  List<ExerciseSet> fromSql(String fromDb) {
    final List<dynamic> jsonList = jsonDecode(fromDb) as List<dynamic>;
    return jsonList
        .map((json) => ExerciseSet.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  String toSql(List<ExerciseSet> value) {
    return jsonEncode(value.map((set) => set.toJson()).toList());
  }
}
