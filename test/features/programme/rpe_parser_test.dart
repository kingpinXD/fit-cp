import 'package:fit_cp/features/programme/rpe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDefaultRpe', () {
    test('parse range takes higher value', () {
      expect(parseDefaultRpe('9-10'), 10);
    });

    test('parse single value', () {
      expect(parseDefaultRpe('8'), 8);
    });

    test('parse empty returns default 5', () {
      expect(parseDefaultRpe(''), 5);
    });

    test('parse blank returns default 5', () {
      expect(parseDefaultRpe('  '), 5);
    });

    test('parse range 7-8 takes 8', () {
      expect(parseDefaultRpe('7-8'), 8);
    });

    test('parse range 8-9 takes 9', () {
      expect(parseDefaultRpe('8-9'), 9);
    });

    test('parse non-numeric returns default 5', () {
      expect(parseDefaultRpe('See Notes'), 5);
    });

    test('parse N/A returns default 5', () {
      expect(parseDefaultRpe('N/A'), 5);
    });

    test('parse value clamped to 10 max', () {
      expect(parseDefaultRpe('12'), 10);
    });

    test('parse value clamped to 1 min', () {
      expect(parseDefaultRpe('0'), 1);
    });
  });
}
