import 'dart:io';

import 'package:fit_cp/data/parsers/programme_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('ProgrammeJsonParser', () {
    test('parses essentials_2x bundled JSON', () {
      final json = File('test/resources/essentials_2x.json').readAsStringSync();
      final exercises = ProgrammeJsonParser.parse(json).views;
      expect(exercises, isNotEmpty);
      // bundled essentials_2x has 12 weeks × 2 days × ~7-8 exercises ≈ 180
      expect(exercises.length, 180);

      final first = exercises.first;
      expect(first.weekNumber, 1);
      expect(first.dayName, 'Full Body A');
      expect(first.exerciseName, 'Flat DB Press (Heavy)');
      expect(first.warmupSets, '2-3');
      expect(first.rpe, '8-9');
      expect(first.videoUrl, contains('youtu.be'));
    });

    test('empty weeks array yields empty list', () {
      final exercises = ProgrammeJsonParser.parse('{"weeks": []}').views;
      expect(exercises, isEmpty);
    });

    test('missing optional fields fall back to defaults', () {
      const json = '''
      {
        "weeks": [
          {"week": 1, "days": [
            {"day": "A", "exercises": [
              {"name": "Squat", "sets": 3, "reps": "5"}
            ]}
          ]}
        ]
      }
      ''';
      final ex = ProgrammeJsonParser.parse(json).views.first;
      expect(ex.exerciseName, 'Squat');
      expect(ex.sets, 3);
      expect(ex.reps, '5');
      expect(ex.rpe, '');
      expect(ex.warmupSets, '0');
      expect(ex.notes, '');
      expect(ex.videoUrl, '');
    });

    test('orderIndex defaults to running list length when omitted', () {
      const json = '''
      {
        "weeks": [
          {"week": 1, "days": [
            {"day": "A", "exercises": [
              {"name": "A", "sets": 1, "reps": "5"},
              {"name": "B", "sets": 1, "reps": "5"}
            ]}
          ]}
        ]
      }
      ''';
      final exercises = ProgrammeJsonParser.parse(json).views;
      expect(exercises[0].orderIndex, 0);
      expect(exercises[1].orderIndex, 1);
    });

    test('explicit order field is preserved', () {
      const json = '''
      {
        "weeks": [
          {"week": 1, "days": [
            {"day": "A", "exercises": [
              {"name": "A", "sets": 1, "reps": "5", "order": 7}
            ]}
          ]}
        ]
      }
      ''';
      expect(ProgrammeJsonParser.parse(json).views.first.orderIndex, 7);
    });
  });
}
