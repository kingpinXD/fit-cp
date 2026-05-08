import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ProgrammeJsonParser {
  static List<ExercisesCompanion> parse(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final weeks = (root['weeks'] as List?) ?? const [];
    final exercises = <ExercisesCompanion>[];

    for (final w in weeks) {
      final weekObj = w as Map<String, dynamic>;
      final weekNumber = weekObj['week'] as int;
      final days = (weekObj['days'] as List?) ?? const [];

      for (final d in days) {
        final dayObj = d as Map<String, dynamic>;
        final dayName = dayObj['day'] as String;
        final exArr = (dayObj['exercises'] as List?) ?? const [];

        for (final e in exArr) {
          final exObj = e as Map<String, dynamic>;
          exercises.add(
            ExercisesCompanion.insert(
              weekNumber: weekNumber,
              dayName: dayName,
              exerciseName: exObj['name'] as String,
              sets: exObj['sets'] as int,
              reps: exObj['reps'] as String,
              orderIndex: (exObj['order'] as int?) ?? exercises.length,
              rpe: Value(_str(exObj, 'rpe')),
              rest: Value(_str(exObj, 'rest')),
              notes: Value(_str(exObj, 'notes')),
              warmupSets: Value(_str(exObj, 'warmupSets', defaultValue: '0')),
              sub1: Value(_str(exObj, 'sub1')),
              sub2: Value(_str(exObj, 'sub2')),
              videoUrl: Value(_str(exObj, 'videoUrl')),
              sub1VideoUrl: Value(_str(exObj, 'sub1VideoUrl')),
              sub2VideoUrl: Value(_str(exObj, 'sub2VideoUrl')),
            ),
          );
        }
      }
    }

    return exercises;
  }

  static String _str(
    Map<String, dynamic> obj,
    String key, {
    String defaultValue = '',
  }) {
    final v = obj[key];
    if (v == null) return defaultValue;
    return v.toString();
  }
}
