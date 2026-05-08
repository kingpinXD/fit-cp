import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../database/app_database.dart';

/// Parses workout programme XLSX files into Exercise rows.
///
/// Auto-detects two format families:
/// - Week-based (Essentials/PPL): "Week N" headers, day rows, exercise rows
/// - Header-based (weekly plan): row 1 column headers, day labels in column A
class XlsxParser {
  static final RegExp _weekPattern =
      RegExp(r'^Week\s+(\d+).*', caseSensitive: false);
  static const _skipValues = {
    'exercise',
    'warm-up sets',
    'working sets',
    'reps',
    'load',
    'rpe',
    'rest',
    'notes',
  };
  static final RegExp _dayLabelPattern =
      RegExp(r'Day\s+\d+\s*[–\-]\s*(.+)', caseSensitive: false);

  static List<ExercisesCompanion> parse(Uint8List bytes) {
    final fixedBytes = _normalizeXlsxBytes(bytes);
    final excel = Excel.decodeBytes(fixedBytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    final hyperlinks = _readHyperlinks(fixedBytes, sheetIndex: 1);

    final format = _detectFormat(sheet);
    return format == _Format.weekBased
        ? _parseWeekBased(sheet, hyperlinks)
        : _parseHeaderBased(sheet);
  }

  /// Some XLSX writers store relationship targets as absolute paths (e.g.
  /// `/xl/worksheets/sheet1.xml`). The `excel` package builds paths as
  /// `xl/$target`, which produces an invalid path when target is absolute.
  /// Strip leading slashes from rels targets so the parser can find the
  /// embedded files.
  static Uint8List _normalizeXlsxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      var modified = false;
      final fixed = Archive();
      for (final file in archive.files) {
        if (file.isFile &&
            file.name.startsWith('xl/worksheets/') &&
            file.name.endsWith('.xml')) {
          final raw = file.content as List<int>;
          final content = utf8.decode(raw, allowMalformed: true);
          // Empty inline-string cells (`<c t="inlineStr"></c>`) crash the
          // `excel` parser because it looks up the `<t>` child. Give them
          // an empty `<is><t/></is>` payload so the parser can read it.
          final repaired = content.replaceAllMapped(
            RegExp(r'<c([^>]+t="inlineStr"[^>]*)></c>'),
            (m) => '<c${m.group(1)}><is><t/></is></c>',
          );
          if (repaired != content) {
            modified = true;
            final newBytes = utf8.encode(repaired);
            fixed.addFile(
              ArchiveFile(file.name, newBytes.length, newBytes),
            );
            continue;
          }
        }
        if (file.isFile && file.name.endsWith('.rels')) {
          final content = _decodeUtf8(file.content);
          if (content.contains('Target="/')) {
            final relsDir = _relsParent(file.name);
            final repaired = content.replaceAllMapped(
              RegExp(r'Target="/+([^"]*)"'),
              (m) {
                final abs = m.group(1)!;
                final relative = abs.startsWith('$relsDir/')
                    ? abs.substring(relsDir.length + 1)
                    : abs;
                return 'Target="$relative"';
              },
            );
            modified = true;
            final newBytes = utf8.encode(repaired);
            fixed.addFile(
              ArchiveFile(file.name, newBytes.length, newBytes),
            );
            continue;
          }
        }
        if (file.isFile) {
          final raw = file.content as List<int>;
          fixed.addFile(ArchiveFile(file.name, raw.length, raw));
        } else {
          fixed.addFile(file);
        }
      }
      if (!modified) return bytes;
      final encoded = ZipEncoder().encode(fixed);
      return Uint8List.fromList(encoded!);
    } catch (_) {
      return bytes;
    }
  }

  // ---- Format detection ----

  static _Format _detectFormat(Sheet sheet) {
    final scanLimit = sheet.maxRows < 21 ? sheet.maxRows : 21;
    for (var i = 0; i < scanLimit; i++) {
      final row = _row(sheet, i);
      final colLimit = row.length < 6 ? row.length : 6;
      for (var j = 0; j < colLimit; j++) {
        final value = _cellString(row, j).trim();
        if (_weekPattern.hasMatch(value)) return _Format.weekBased;
      }
    }

    final firstRow = _row(sheet, 0);
    if (firstRow.isNotEmpty) {
      const headerNames = {
        'exercise',
        'exercises',
        'sets',
        'reps',
        'day',
        'days',
        'reps/duration',
        'notes',
        'note',
        'focus',
        'description',
      };
      var headerCount = 0;
      final colLimit = firstRow.length < 11 ? firstRow.length : 11;
      for (var j = 0; j < colLimit; j++) {
        final value = _cellString(firstRow, j).trim().toLowerCase();
        if (headerNames.contains(value)) headerCount++;
      }
      if (headerCount >= 2) return _Format.headerBased;
    }

    return _Format.weekBased;
  }

  // ---- Week-based parsing ----

  static List<ExercisesCompanion> _parseWeekBased(
    Sheet sheet,
    Map<String, String> hyperlinks,
  ) {
    final offset = _detectColumnOffset(sheet);
    final exercises = <ExercisesCompanion>[];

    int? currentWeek;
    String? currentDay;
    final dayCounters = <String, int>{};
    final dayCountsPerWeek = <String, int>{};

    for (var i = 0; i < sheet.maxRows; i++) {
      final row = _row(sheet, i);
      final labelCol = _cellString(row, offset);
      final exerciseCol = _cellString(row, offset + 1);

      if (labelCol.isNotBlank) {
        final weekMatch = _weekPattern.matchAsPrefix(labelCol.trim());
        if (weekMatch != null && weekMatch.end == labelCol.trim().length) {
          currentWeek = int.parse(weekMatch.group(1)!);
          currentDay = null;
          dayCountsPerWeek.clear();
          continue;
        }

        if (_isDayName(labelCol) && currentWeek != null) {
          final dayLabel = labelCol.trim();
          final count = (dayCountsPerWeek[dayLabel] ?? 0) + 1;
          dayCountsPerWeek[dayLabel] = count;
          currentDay = count > 1 ? '$dayLabel #$count' : dayLabel;

          if (exerciseCol.isNotBlank) {
            final sets = _numericCell(row, offset + 3);
            if (sets != null) {
              final key = '$currentWeek-$currentDay';
              dayCounters[key] = (dayCounters[key] ?? 0) + 1;
              exercises.add(_buildWeekBasedExercise(
                row, i, offset, currentWeek, currentDay, dayCounters[key]!,
                hyperlinks,
              ));
            }
          }
          continue;
        }

        continue;
      }

      if (exerciseCol.isNotBlank && currentDay != null && currentWeek != null) {
        final sets = _numericCell(row, offset + 3);
        if (sets != null) {
          final key = '$currentWeek-$currentDay';
          dayCounters[key] = (dayCounters[key] ?? 0) + 1;
          exercises.add(_buildWeekBasedExercise(
            row, i, offset, currentWeek, currentDay, dayCounters[key]!,
            hyperlinks,
          ));
        }
      }
    }

    return exercises;
  }

  static ExercisesCompanion _buildWeekBasedExercise(
    List<Data?> row,
    int rowIndex,
    int offset,
    int weekNumber,
    String dayName,
    int orderIndex,
    Map<String, String> hyperlinks,
  ) {
    final exerciseName = _cellString(row, offset + 1).trim();
    final warmup = _parseDateOrNumber(_cell(row, offset + 2), defaultValue: '0');
    final sets = _numericCell(row, offset + 3) ?? 1;
    final reps = _cellString(row, offset + 4).trim();
    final rpe = _parseDateOrNumber(_cell(row, offset + 6));
    final rest = _cellString(row, offset + 7).trim();
    final sub1 = _cellString(row, offset + 8).trim();
    final sub2 = _cellString(row, offset + 9).trim();
    final notes = _cellString(row, offset + 10).trim();
    final videoUrl = hyperlinks[_cellRef(rowIndex, offset + 1)] ?? '';
    final sub1VideoUrl = hyperlinks[_cellRef(rowIndex, offset + 8)] ?? '';
    final sub2VideoUrl = hyperlinks[_cellRef(rowIndex, offset + 9)] ?? '';

    return ExercisesCompanion.insert(
      weekNumber: weekNumber,
      dayName: dayName,
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      orderIndex: orderIndex,
      rpe: Value(rpe),
      rest: Value(rest),
      notes: Value(notes),
      warmupSets: Value(warmup),
      sub1: Value(sub1),
      sub2: Value(sub2),
      videoUrl: Value(videoUrl),
      sub1VideoUrl: Value(sub1VideoUrl),
      sub2VideoUrl: Value(sub2VideoUrl),
    );
  }

  // ---- Header-based parsing ----

  static List<ExercisesCompanion> _parseHeaderBased(Sheet sheet) {
    final headerRow = _row(sheet, 0);
    if (headerRow.isEmpty) return const [];
    final headers = _buildHeaderMap(headerRow);

    final exerciseCol = headers['exercise'];
    if (exerciseCol == null) return const [];
    final setsCol = headers['sets'];
    final repsCol = headers['reps'];
    final notesCol = headers['notes'];
    final dayCol = headers['day'];

    final exercises = <ExercisesCompanion>[];
    String? currentDay;
    final dayCounters = <String, int>{};

    for (var i = 1; i < sheet.maxRows; i++) {
      final row = _row(sheet, i);
      if (row.isEmpty) continue;

      final dayValue = dayCol != null ? _cellString(row, dayCol).trim() : '';
      if (dayValue.isNotBlank) {
        final extracted = extractDayName(dayValue);
        if (extracted.toLowerCase() == 'rest') continue;
        currentDay = extracted;
      }

      if (currentDay == null) continue;

      final exerciseName = _cellString(row, exerciseCol).trim();
      final setsValue = setsCol != null ? _numericCell(row, setsCol) : null;
      final repsValue = repsCol != null ? _cellString(row, repsCol).trim() : '';
      final notesValue =
          notesCol != null ? _cellString(row, notesCol).trim() : '';

      if (exerciseName.isEmpty) continue;
      final sets = setsValue ?? 1;
      dayCounters[currentDay] = (dayCounters[currentDay] ?? 0) + 1;

      exercises.add(
        ExercisesCompanion.insert(
          weekNumber: 1,
          dayName: currentDay,
          exerciseName: exerciseName,
          sets: sets,
          reps: repsValue,
          orderIndex: dayCounters[currentDay]!,
          notes: Value(notesValue),
        ),
      );
    }

    return exercises;
  }

  static Map<String, int> _buildHeaderMap(List<Data?> row) {
    final map = <String, int>{};
    for (var j = 0; j < row.length; j++) {
      final value = _cellString(row, j).trim().toLowerCase();
      if (const {'exercise', 'exercises'}.contains(value)) {
        map['exercise'] = j;
      } else if (const {'sets', 'set'}.contains(value)) {
        map['sets'] = j;
      } else if (const {'reps', 'rep', 'reps/duration'}.contains(value)) {
        map['reps'] = j;
      } else if (const {'notes', 'note'}.contains(value)) {
        map['notes'] = j;
      } else if (const {'day', 'days'}.contains(value)) {
        map['day'] = j;
      } else if (value == 'rpe') {
        map['rpe'] = j;
      } else if (value == 'rest') {
        map['rest'] = j;
      } else if (const {'warm-up', 'warmup', 'warm-up sets'}.contains(value)) {
        map['warmup'] = j;
      }
    }
    return map;
  }

  /// Extract the meaningful day name from labels like "Day 1 – Push" → "Push".
  static String extractDayName(String raw) {
    final match = _dayLabelPattern.firstMatch(raw.trim());
    return match?.group(1)?.trim() ?? raw.trim();
  }

  // ---- Shared utilities ----

  /// Scan first 20 rows to determine whether week/day labels live in column A
  /// (offset=0) or column B (offset=1).
  static int _detectColumnOffset(Sheet sheet) {
    final scanLimit = sheet.maxRows < 21 ? sheet.maxRows : 21;
    for (var i = 0; i < scanLimit; i++) {
      final row = _row(sheet, i);
      final colA = _cellString(row, 0);
      if (_weekPattern.hasMatch(colA.trim())) return 0;
      final colB = _cellString(row, 1);
      if (_weekPattern.hasMatch(colB.trim())) return 1;
    }
    return 1;
  }

  static bool _isDayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_weekPattern.hasMatch(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    if (_skipValues.any((s) => lower == s)) return false;
    if (lower.contains('suggested')) return false;
    if (lower.contains('rest day')) return false;
    if (lower.contains('mandatory')) return false;
    if (lower.contains('copyright')) return false;
    if (lower.contains('program')) return false;
    if (lower.contains('volume')) return false;
    if (lower.contains('intensity')) return false;
    if (lower.contains('substitution')) return false;
    if (lower.contains('warm-up sets')) return false;
    return true;
  }

  /// Excel stores values like "8-9" as dates (2022-08-09). Extract month-day
  /// as the range. Integers stay as-is. Strings pass through.
  static String _parseDateOrNumber(Data? cell, {String defaultValue = ''}) {
    if (cell == null || cell.value == null) return defaultValue;
    final v = cell.value!;
    if (v is DateCellValue) {
      return '${v.month}-${v.day}';
    }
    if (v is DateTimeCellValue) {
      return '${v.month}-${v.day}';
    }
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final num = v.value;
      if (num == num.toInt().toDouble()) return num.toInt().toString();
      return num.toString();
    }
    if (v is TextCellValue) {
      final text = v.value.toString().trim();
      return text.isEmpty ? defaultValue : text;
    }
    return defaultValue;
  }

  static String _cellString(List<Data?> row, int j) {
    if (j < 0 || j >= row.length) return '';
    final cell = row[j];
    if (cell == null || cell.value == null) return '';
    final v = cell.value!;
    if (v is TextCellValue) return v.value.toString();
    if (v is DateCellValue || v is DateTimeCellValue) return '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final num = v.value;
      if (num == num.toInt().toDouble()) return num.toInt().toString();
      return num.toString();
    }
    return '';
  }

  static int? _numericCell(List<Data?> row, int j) {
    if (j < 0 || j >= row.length) return null;
    final cell = row[j];
    if (cell == null || cell.value == null) return null;
    final v = cell.value!;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value.toInt();
    if (v is TextCellValue) return int.tryParse(v.value.toString().trim());
    return null;
  }

  static Data? _cell(List<Data?> row, int j) {
    if (j < 0 || j >= row.length) return null;
    return row[j];
  }

  static List<Data?> _row(Sheet sheet, int i) {
    if (i < 0 || i >= sheet.maxRows) return const [];
    return sheet.rows[i];
  }

  static String _cellRef(int rowIndex, int colIndex) {
    final col = _columnLetter(colIndex);
    return '$col${rowIndex + 1}';
  }

  static String _columnLetter(int colIndex) {
    var n = colIndex;
    final buf = <String>[];
    while (true) {
      buf.insert(0, String.fromCharCode(65 + (n % 26)));
      n = (n ~/ 26) - 1;
      if (n < 0) break;
    }
    return buf.join();
  }

  // ---- Hyperlink extraction (excel package doesn't expose them) ----

  /// Reads `xl/worksheets/sheetN.xml` + `xl/worksheets/_rels/sheetN.xml.rels`
  /// and returns a map of cell ref ("A12") → hyperlink target URL.
  static Map<String, String> _readHyperlinks(Uint8List bytes, {int sheetIndex = 1}) {
    final result = <String, String>{};
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheetFile =
          archive.findFile('xl/worksheets/sheet$sheetIndex.xml');
      final relsFile = archive
          .findFile('xl/worksheets/_rels/sheet$sheetIndex.xml.rels');
      if (sheetFile == null || relsFile == null) return result;

      final relsDoc = XmlDocument.parse(_decodeUtf8(relsFile.content));
      final rels = <String, String>{};
      for (final rel in relsDoc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        final type = rel.getAttribute('Type') ?? '';
        if (id != null && target != null && type.contains('hyperlink')) {
          rels[id] = target;
        }
      }

      final sheetDoc = XmlDocument.parse(_decodeUtf8(sheetFile.content));
      for (final hl in sheetDoc.findAllElements('hyperlink')) {
        final ref = hl.getAttribute('ref');
        final id = hl.getAttribute('r:id') ?? hl.getAttribute('id');
        final location = hl.getAttribute('location');
        if (ref == null) continue;
        String? target;
        if (id != null && rels.containsKey(id)) {
          target = rels[id];
        } else if (location != null) {
          target = location;
        }
        if (target == null) continue;
        for (final cellRef in _expandRef(ref)) {
          result[cellRef] = target;
        }
      }
    } catch (_) {
      // best-effort; silently fall through if the XLSX is malformed
    }
    return result;
  }

  /// For `xl/_rels/workbook.xml.rels` returns `xl`. For `_rels/.rels`
  /// returns '' (root). Strips the trailing `_rels/<filename>`.
  static String _relsParent(String relsPath) {
    final relsIdx = relsPath.lastIndexOf('_rels/');
    if (relsIdx <= 0) return '';
    return relsPath.substring(0, relsIdx - 1); // -1 to drop trailing '/'
  }

  static String _decodeUtf8(dynamic content) {
    if (content is String) return content;
    if (content is List<int>) return String.fromCharCodes(content);
    return content.toString();
  }

  /// Expand a possibly-multi-cell ref (`A1:B2`) into individual `A1`, `B1`,
  /// `A2`, `B2` refs. Single refs pass through unchanged.
  static List<String> _expandRef(String ref) {
    if (!ref.contains(':')) return [ref];
    return [ref.split(':').first];
  }
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}

enum _Format { weekBased, headerBased }
