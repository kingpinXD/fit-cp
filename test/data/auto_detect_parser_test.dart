import 'dart:io';

import 'package:fit_cp/data/parsers/xlsx_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('AutoDetectParser', () {
    List<ExerciseView> load(String name) {
      final bytes = File('test/resources/programmes/$name').readAsBytesSync();
      return XlsxParser.parse(bytes).views;
    }

    test('weekly plan - produces exercises', () {
      expect(load('weekly_plan.xlsx'), isNotEmpty);
    });

    test('weekly plan - all exercises in week 1', () {
      final exercises = load('weekly_plan.xlsx');
      expect(exercises.every((e) => e.weekNumber == 1), isTrue);
    });

    test('weekly plan - has correct day names', () {
      final days = load('weekly_plan.xlsx').map((e) => e.dayName).toSet();
      expect(days.any((d) => d.contains('Push')), isTrue);
      expect(days.any((d) => d.contains('Pull')), isTrue);
      expect(days.any((d) => d.contains('Legs') || d.contains('Core')), isTrue);
      expect(days.any((d) => d.contains('Upper')), isTrue);
    });

    test('weekly plan - push day has 6 exercises', () {
      final pushExercises = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Push'));
      expect(pushExercises.length, 6);
    });

    test('weekly plan - pull day has 5 exercises', () {
      final pullExercises = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Pull'));
      expect(pullExercises.length, 5);
    });

    test('weekly plan - first exercise has correct data', () {
      final first = load('weekly_plan.xlsx').first;
      expect(first.exerciseName, 'Incline Dumbbell Press');
      expect(first.sets, 3);
      expect(first.reps.contains('10'), isTrue);
      expect(first.orderIndex, 1);
    });

    test('weekly plan - exercises with notes preserved', () {
      final exercises = load('weekly_plan.xlsx');
      final withNotes = exercises.where((e) => e.notes.trim().isNotEmpty);
      expect(withNotes, isNotEmpty);
      final ote = exercises
          .firstWhere((e) => e.exerciseName == 'Overhead Triceps Extension');
      expect(ote.notes, 'Light, controlled');
    });

    test('weekly plan - exercises without sets default to 1', () {
      final cardio = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Cardio'));
      expect(cardio.every((e) => e.sets >= 1), isTrue);
    });

    test('weekly plan - duration reps preserved as string', () {
      final plank = load('weekly_plan.xlsx')
          .firstWhere((e) => e.exerciseName == 'Plank');
      expect(
        plank.reps.contains('sec') || plank.reps.contains('30'),
        isTrue,
      );
    });

    test('weekly plan - skips note-only rows', () {
      final exercises = load('weekly_plan.xlsx');
      final noteAsExercise = exercises
          .where((e) => e.exerciseName.contains('Avoid'))
          .firstOrNull;
      expect(noteAsExercise, isNull);
    });

    test('weekly plan - missing fields are empty strings', () {
      final exercises = load('weekly_plan.xlsx');
      expect(exercises.every((e) => e.rpe.trim().isEmpty), isTrue);
      expect(
        exercises.every((e) => e.warmupSets == '0' || e.warmupSets.isEmpty),
        isTrue,
      );
    });

    test('weekly plan - recovery day exercise stored', () {
      final recovery = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Recovery'))
          .toList();
      expect(recovery.length, 1);
      expect(recovery.first.exerciseName, 'Walking / Cycling / Mobility');
      expect(recovery.first.sets, 1);
    });

    test('weekly plan - cardio day exercises parsed', () {
      final cardio = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Cardio'))
          .toList();
      expect(cardio.length, 4);
      expect(cardio.first.exerciseName, 'Incline treadmill walk');
    });

    test('weekly plan - rest day has no exercises', () {
      final rest = load('weekly_plan.xlsx')
          .where((e) => e.dayName.contains('Rest'));
      expect(rest, isEmpty);
    });

    test('weekly plan - order indices sequential per day', () {
      final exercises = load('weekly_plan.xlsx');
      final grouped = <String, List<ExerciseView>>{};
      for (final e in exercises) {
        grouped.putIfAbsent(e.dayName, () => []).add(e);
      }
      grouped.forEach((day, list) {
        final indices = list.map((e) => e.orderIndex).toList();
        expect(
          indices,
          List.generate(list.length, (i) => i + 1),
          reason: '$day order indices',
        );
      });
    });

    test('existing essentials format still works after auto-detect changes',
        () {
      final exercises = load('essentials_5x.xlsx');
      expect(exercises.length, 324);
      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days.length, 5);
    });
  });
}
