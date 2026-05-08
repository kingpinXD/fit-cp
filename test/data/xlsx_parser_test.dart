import 'dart:io';

import 'package:fit_cp/data/parsers/xlsx_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('XlsxParser', () {
    List<ExerciseView> load(String name) {
      final bytes = File('test/resources/programmes/$name').readAsBytesSync();
      return XlsxParser.parse(bytes).views;
    }

    test('parse essentials 5x - correct week and day count', () {
      final exercises = load('essentials_5x.xlsx');
      final weeks = exercises.map((e) => e.weekNumber).toSet().toList()..sort();
      expect(weeks.length, 12);

      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days.length, 5);
      expect(week1Days, containsAll(['Upper', 'Lower', 'Push', 'Pull', 'Legs']));
    });

    test('parse essentials 5x - correct exercise count per day', () {
      final exercises = load('essentials_5x.xlsx');
      final week1Upper = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Upper');
      expect(week1Upper.length, 7);

      final week1Lower = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Lower');
      expect(week1Lower.length, 5);
    });

    test('parse essentials 5x - first exercise parsed correctly', () {
      final exercises = load('essentials_5x.xlsx');
      final first = exercises.firstWhere((e) =>
          e.weekNumber == 1 && e.dayName == 'Upper' && e.orderIndex == 1);
      expect(first.exerciseName, 'Flat DB Press (Heavy)');
      expect(first.rpe, '8-9');
      expect(first.warmupSets, '2-3');
      expect(first.sets, 1);
      expect(first.reps, '4-6');
    });

    test('parse essentials 5x - dropset in reps preserved', () {
      final exercises = load('essentials_5x.xlsx');
      final cableRow = exercises.firstWhere((e) =>
          e.weekNumber == 1 &&
          e.dayName == 'Upper' &&
          e.exerciseName == 'Seated Cable Row');
      expect(cableRow.reps.contains('dropset'), isTrue);
    });

    test('parse essentials 5x - exercises change between phases', () {
      final exercises = load('essentials_5x.xlsx');
      final w1 = exercises.firstWhere(
          (e) => e.weekNumber == 1 && e.dayName == 'Upper' && e.orderIndex == 1);
      final w5 = exercises.firstWhere(
          (e) => e.weekNumber == 5 && e.dayName == 'Upper' && e.orderIndex == 1);
      expect(w1.exerciseName, isNot(w5.exerciseName));
    });

    test('parse essentials 5x - day order preserved', () {
      final exercises = load('essentials_5x.xlsx');
      final week1 = exercises.where((e) => e.weekNumber == 1).toList();
      final dayOrder = <String>[];
      for (final e in week1) {
        if (!dayOrder.contains(e.dayName)) dayOrder.add(e.dayName);
      }
      expect(dayOrder, ['Upper', 'Lower', 'Push', 'Pull', 'Legs']);
    });

    test('parse essentials 5x - notes populated', () {
      final exercises = load('essentials_5x.xlsx');
      final withNotes = exercises.where((e) => e.notes.trim().isNotEmpty);
      expect(withNotes, isNotEmpty);
    });

    test('parse essentials 2x - full body days', () {
      final exercises = load('essentials_2x.xlsx');
      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days, containsAll(['Full Body A', 'Full Body B']));
      expect(week1Days.length, 2);
    });

    test('parse essentials 2x - exercise count per day', () {
      final exercises = load('essentials_2x.xlsx');
      final week1A = exercises
          .where((e) => e.weekNumber == 1 && e.dayName == 'Full Body A');
      expect(week1A.length, 8);
      final week1B = exercises
          .where((e) => e.weekNumber == 1 && e.dayName == 'Full Body B');
      expect(week1B.length, 7);
    });

    test('parse essentials 3x - mixed day names', () {
      final exercises = load('essentials_3x.xlsx');
      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days.length, 3);
      expect(week1Days, containsAll(['Full Body', 'Upper', 'Lower']));
    });

    test('parse essentials 4x - upper lower split with unique names', () {
      final exercises = load('essentials_4x.xlsx');
      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days.length, 4);
      expect(
        week1Days,
        containsAll(['Upper', 'Lower', 'Upper #2', 'Lower #2']),
      );
    });

    test('parse essentials 4x - four sessions per week', () {
      final exercises = load('essentials_4x.xlsx');
      final upper1 = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Upper');
      final upper2 = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Upper #2');
      final lower1 = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Lower');
      final lower2 = exercises.where(
          (e) => e.weekNumber == 1 && e.dayName == 'Lower #2');
      expect(upper1.length, 7);
      expect(upper2.length, 7);
      expect(lower1.length, 5);
      expect(lower2.length, 5);
    });

    test('parse ppl 5x - column A layout detected', () {
      final exercises = load('ppl_5x.xlsx');
      expect(exercises, isNotEmpty);
      final week1Days = exercises
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(week1Days, isNotEmpty);
      expect(
        week1Days.any(
            (d) => d.contains('Push') || d.contains('Pull') || d.contains('Legs')),
        isTrue,
      );
    });

    test('parse ppl 5x - all five days present', () {
      final exercises = load('ppl_5x.xlsx');
      final dayNames = exercises.map((e) => e.dayName).toSet();
      expect(dayNames.length, 5);
      expect(
        dayNames,
        containsAll(['Push #1', 'Pull #1', 'Legs #1', 'Upper #1', 'Lower #1']),
      );
    });

    test('parse ppl 5x - exercises have valid data', () {
      final exercises = load('ppl_5x.xlsx');
      final firstPush =
          exercises.where((e) => e.dayName.contains('Push')).firstOrNull;
      expect(firstPush, isNotNull);
      expect(firstPush!.exerciseName.trim(), isNotEmpty);
      expect(firstPush.sets, greaterThan(0));
      expect(firstPush.reps.trim(), isNotEmpty);
    });

    test('parse ppl 5x - push day has correct exercises', () {
      final exercises = load('ppl_5x.xlsx');
      final push = exercises.where((e) => e.dayName == 'Push #1').toList();
      expect(push.length, 6);
      expect(push.first.exerciseName, 'Bench Press');
    });

    test('parse ppl 5x - string RPE values preserved', () {
      final exercises = load('ppl_5x.xlsx');
      final seeNotes = exercises.where((e) => e.rpe == 'See Notes');
      expect(seeNotes, isNotEmpty);
    });

    test('parse ppl 5x - NA RPE values preserved', () {
      final exercises = load('ppl_5x.xlsx');
      final na = exercises.where((e) => e.rpe.toLowerCase() == 'n/a');
      expect(na, isNotEmpty);
    });

    test('all files parse without exceptions', () {
      const files = [
        'essentials_2x.xlsx',
        'essentials_3x.xlsx',
        'essentials_4x.xlsx',
        'essentials_5x.xlsx',
        'ppl_5x.xlsx',
      ];
      for (final file in files) {
        final exercises = load(file);
        expect(exercises, isNotEmpty, reason: '$file should produce exercises');
        for (final ex in exercises) {
          expect(ex.exerciseName.trim(), isNotEmpty,
              reason: '$file: exercise name');
          expect(ex.sets, greaterThan(0), reason: '$file: sets > 0');
          expect(ex.reps.trim(), isNotEmpty, reason: '$file: reps');
          expect(ex.weekNumber, greaterThan(0), reason: '$file: week > 0');
          expect(ex.dayName.trim(), isNotEmpty, reason: '$file: dayName');
        }
      }
    });

    test('all exercises have sequential order indices within each day', () {
      const files = [
        'essentials_2x.xlsx',
        'essentials_3x.xlsx',
        'essentials_4x.xlsx',
        'essentials_5x.xlsx',
        'ppl_5x.xlsx',
      ];
      for (final file in files) {
        final exercises = load(file);
        final grouped = <String, List<ExerciseView>>{};
        for (final e in exercises) {
          grouped.putIfAbsent('${e.weekNumber}-${e.dayName}', () => []).add(e);
        }
        grouped.forEach((key, list) {
          final indices = list.map((e) => e.orderIndex).toList();
          expect(
            indices,
            List.generate(list.length, (i) => i + 1),
            reason: '$file: $key should have sequential order indices',
          );
        });
      }
    });

    test('hyperlinks on exercise names parsed when present', () {
      final exercises = load('essentials_5x.xlsx');
      final withVideo = exercises.where((e) => e.videoUrl.isNotEmpty);
      expect(withVideo, isNotEmpty,
          reason: 'essentials_5x has hyperlinks on most exercise names');
    });
  });
}
