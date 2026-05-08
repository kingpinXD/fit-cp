import 'package:fit_cp/data/parsers/programme_name_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgrammeNameNormalizer', () {
    String normalize(String filename, [String parent = '']) =>
        ProgrammeNameNormalizer.normalize(filename, parentFolder: parent);

    test('essentials program 2x', () {
      expect(normalize('The Essentials Program 2x.xlsx'), 'essentials_2x');
    });

    test('essentials program 5x', () {
      expect(normalize('The Essentials Program 5x.xlsx'), 'essentials_5x');
    });

    test('edited ppl 5x', () {
      expect(normalize('Edited PPL 5x.xlsx'), 'ppl_5x');
    });

    test('powerbuilding 6x with hyphenated spreadsheet', () {
      expect(
        normalize('POWERBUILDING-6x-Spreadsheet.xlsx'),
        'powerbuilding-6x',
      );
    });

    test('4x with parent folder fallback', () {
      expect(
        normalize('4x - SPREADSHEET.xlsx', '2.0 Powerbuilding Program'),
        '2.0_powerbuilding_4x',
      );
    });

    test('5-6x with parent folder fallback', () {
      expect(
        normalize('5-6x - SPREADSHEET.xlsx', '2.0 Powerbuilding Program'),
        '2.0_powerbuilding_5-6x',
      );
    });

    test('powerbuilding 3.0', () {
      expect(normalize('PowerBuilding 3.0.xlsx'), 'powerbuilding_3.0');
    });

    test('pure bodybuilding full body with underscores and dash', () {
      expect(
        normalize('Pure_Bodybuilding_-_Full_Body.xlsx'),
        'pure_bodybuilding_full_body',
      );
    });

    test('pure bodybuilding phase 2 full body sheet', () {
      expect(
        normalize('Pure Bodybuilding Phase 2 - Full Body Sheet.xlsx'),
        'pure_bodybuilding_phase_2_full_body',
      );
    });

    test('full body program 4x', () {
      expect(normalize('Full Body Program - 4x.xlsx'), 'full_body_4x');
    });

    test('full body program 5x', () {
      expect(normalize('Full Body Program - 5x.xlsx'), 'full_body_5x');
    });

    test('ultimate push pull legs system 4x', () {
      expect(
        normalize('The_Ultimate_Push_Pull_Legs_System_-_4x.xlsx'),
        'ultimate_push_pull_legs_system_4x',
      );
    });

    test('essentials program no variant', () {
      expect(normalize('The Essentials Program.xlsx'), 'essentials');
    });
  });
}
