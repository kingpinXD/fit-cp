import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/day_info.dart';
import '../models/exercise_history_entry.dart';
import '../models/import_result.dart';
import '../parsers/programme_json_parser.dart';
import '../parsers/xlsx_parser.dart';

typedef AssetLoader = Future<String> Function(String path);

/// Single source of truth for the active programme, exercise + log queries,
/// imports, exports, and bundled-asset preload. Mirrors the Kotlin
/// `ProgrammeRepository` 1:1.
class ProgrammeRepository {
  ProgrammeRepository({
    required AppDatabase db,
    required SharedPreferences prefs,
    AssetLoader? assetLoader,
  })  : _db = db,
        _prefs = prefs,
        _assetLoader = assetLoader ?? rootBundle.loadString;

  static const String _prefsKey = 'programme_name';
  static const Map<String, String> bundledProgrammes = {
    'essentials_2x': 'essentials_2x.json',
    'essentials_3x': 'essentials_3x.json',
    'essentials_4x': 'essentials_4x.json',
    'essentials_5x': 'essentials_5x.json',
  };

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final AssetLoader _assetLoader;

  // ---- Active programme name ----

  String getProgrammeName() => _prefs.getString(_prefsKey) ?? '';

  Future<void> setProgrammeName(String name) async {
    await _prefs.setString(_prefsKey, name);
  }

  // ---- Existence checks ----

  Stream<bool> hasProgramme() => _db.exerciseDao
      .watchCountByProgramme(getProgrammeName())
      .map((c) => c > 0);

  Stream<bool> hasProgrammeByName(String name) =>
      _db.exerciseDao.watchCountByProgramme(name).map((c) => c > 0);

  Future<bool> programmeExists(String name) async {
    if (await _db.programmeDao.exists(name)) return true;
    return (await _db.exerciseDao.countByProgramme(name)) > 0;
  }

  // ---- Imports ----

  Future<ImportResult> importProgrammeFromJson(String json, String name) async {
    if (await programmeExists(name)) {
      await setProgrammeName(name);
      return ImportResult.switched;
    }
    final parsed = ProgrammeJsonParser.parse(json)
        .map((c) => c.copyWith(programmeName: Value(name)))
        .toList();
    await _db.exerciseDao.insertAll(parsed);
    await _db.programmeDao.upsert(
      ProgrammesCompanion.insert(name: name, importedAt: _nowIso()),
    );
    await setProgrammeName(name);
    return ImportResult.imported;
  }

  Future<ImportResult> importProgrammeFromXlsx(
    Uint8List bytes,
    String name,
  ) async {
    if (await programmeExists(name)) {
      await setProgrammeName(name);
      return ImportResult.switched;
    }
    final parsed = XlsxParser.parse(bytes)
        .map((c) => c.copyWith(programmeName: Value(name)))
        .toList();
    await _db.exerciseDao.insertAll(parsed);
    await _db.programmeDao.upsert(
      ProgrammesCompanion.insert(name: name, importedAt: _nowIso()),
    );
    await setProgrammeName(name);
    return ImportResult.imported;
  }

  // ---- Delete ----

  Future<void> deleteProgramme() async {
    final name = getProgrammeName();
    if (name.isNotEmpty) {
      await _db.exerciseLogDao.deleteByProgramme(name);
      await _db.exerciseDao.deleteByProgramme(name);
      await _db.programmeDao.deleteByName(name);
    }
    await setProgrammeName('');
  }

  // ---- Active-programme queries ----

  Stream<List<ExerciseRow>> getExercises(int weekNumber, String dayName) =>
      _db.exerciseDao.watchExercises(getProgrammeName(), weekNumber, dayName);

  Stream<List<int>> getDistinctWeeks() =>
      _db.exerciseDao.watchDistinctWeeks(getProgrammeName());

  Stream<List<int>> getDistinctWeeksByName(String name) =>
      _db.exerciseDao.watchDistinctWeeks(name);

  Stream<List<String>> getDistinctDays(int weekNumber) =>
      _db.exerciseDao.watchDistinctDays(getProgrammeName(), weekNumber);

  Stream<List<String>> getCompletedDays(int weekNumber) =>
      _db.exerciseDao.watchCompletedDays(getProgrammeName(), weekNumber);

  Stream<List<int>> getCompletedWeeks() =>
      _db.exerciseDao.watchCompletedWeeks(getProgrammeName());

  Stream<List<int>> getCompletedWeeksByName(String name) =>
      _db.exerciseDao.watchCompletedWeeks(name);

  Future<DayInfo?> getFirstIncompleteDay() =>
      _db.exerciseDao.getFirstIncompleteDay(getProgrammeName());

  Stream<ExerciseLogRow?> getLog(int exerciseId) =>
      _db.exerciseLogDao.watchLog(exerciseId);

  Stream<List<ExerciseLogRow>> getLogsForDay(int weekNumber, String dayName) =>
      _db.exerciseLogDao
          .watchLogsForDay(getProgrammeName(), weekNumber, dayName);

  Future<ExerciseLogRow?> getLogSync(int exerciseId) =>
      _db.exerciseLogDao.getLogSync(exerciseId);

  Stream<List<ExerciseHistoryEntry>> getHistory(
    String exerciseName,
    int currentWeek,
  ) =>
      _db.exerciseLogDao
          .watchHistory(getProgrammeName(), exerciseName, currentWeek);

  Future<void> saveLog(ExerciseLogsCompanion log) =>
      _db.exerciseLogDao.upsert(log);

  Stream<List<ProgrammeRow>> getAvailableProgrammes() =>
      _db.programmeDao.watchAll();

  // ---- Export ----

  Future<String> buildExportJson(String programmeName, String identifier) async {
    final name = programmeName.isEmpty ? getProgrammeName() : programmeName;
    final allExercises = await _db.exerciseDao.getAllExercises(name);
    final exportLogs = await _db.exerciseLogDao.getExportLogs(name);

    final weekMap = <int, Map<String, List<ExerciseRow>>>{};
    for (final ex in allExercises) {
      final dayMap = weekMap.putIfAbsent(ex.weekNumber, () => {});
      dayMap.putIfAbsent(ex.dayName, () => []).add(ex);
    }

    final weeksJson = <Map<String, dynamic>>[];
    weekMap.forEach((weekNum, dayMap) {
      final daysJson = <Map<String, dynamic>>[];
      dayMap.forEach((dayName, exercises) {
        daysJson.add({
          'day': dayName,
          'exercises': exercises
              .map((ex) => {
                    'name': ex.exerciseName,
                    'sets': ex.sets,
                    'reps': ex.reps,
                    'rpe': ex.rpe,
                    'rest': ex.rest,
                    'warmupSets': ex.warmupSets,
                    'notes': ex.notes,
                    'order': ex.orderIndex,
                    'sub1': ex.sub1,
                    'sub2': ex.sub2,
                  })
              .toList(),
        });
      });
      weeksJson.add({'week': weekNum, 'days': daysJson});
    });

    final root = <String, dynamic>{
      'programmeName': name,
      'identifier': identifier,
      'exportDate': _nowIso(),
      'programme': {'weeks': weeksJson},
      'logs': exportLogs
          .map((log) => {
                'exerciseName': log.exerciseName,
                'weekNumber': log.weekNumber,
                'dayName': log.dayName,
                'userWeight': log.userWeight,
                'equipmentType': log.equipmentType,
                'observedRpe': log.observedRpe,
                'userComments': log.userComments,
                'status': log.status,
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  // ---- Preload + housekeeping ----

  Future<void> preloadProgrammes() async {
    await _cleanupLegacyNames();
    await _repair4xDayNames();
    await _deduplicateExercises();

    for (final entry in bundledProgrammes.entries) {
      final name = entry.key;
      final assetFile = entry.value;
      if (await programmeExists(name)) continue;
      final json = await _assetLoader('assets/programmes/$assetFile');
      final parsed = ProgrammeJsonParser.parse(json)
          .map((c) => c.copyWith(programmeName: Value(name)))
          .toList();
      await _db.exerciseDao.insertAll(parsed);
      await _db.programmeDao.upsert(
        ProgrammesCompanion.insert(name: name, importedAt: _nowIso()),
      );
    }
  }

  Future<void> _deduplicateExercises() async {
    const expected = {
      'essentials_2x': 180,
      'essentials_3x': 240,
      'essentials_4x': 288,
      'essentials_5x': 324,
    };
    for (final entry in expected.entries) {
      final actual = await _db.exerciseDao.countByProgramme(entry.key);
      if (actual > entry.value) {
        await _db.exerciseDao
            .deduplicateByProgramme(entry.key, entry.value);
      }
    }
  }

  Future<void> _repair4xDayNames() async {
    const name4x = 'essentials_4x';
    final count = await _db.exerciseDao.countByProgramme(name4x);
    if (count == 0) return;

    final all = await _db.exerciseDao.getAllExercises(name4x);
    final week1Days = all
        .where((e) => e.weekNumber == 1)
        .map((e) => e.dayName)
        .toSet();
    if (week1Days.length < 4) {
      await _db.exerciseDao.deleteByProgramme(name4x);
      await _db.programmeDao.deleteByName(name4x);
    }
  }

  Future<void> _cleanupLegacyNames() async {
    const legacyMap = {
      'the_essentials_2x': 'essentials_2x',
      'the_essentials_3x': 'essentials_3x',
      'the_essentials_4x': 'essentials_4x',
      'the_essentials_5x': 'essentials_5x',
      'Essentials 2x': 'essentials_2x',
      'Essentials 3x': 'essentials_3x',
      'Essentials 4x': 'essentials_4x',
      'Essentials 5x': 'essentials_5x',
    };
    for (final entry in legacyMap.entries) {
      final oldName = entry.key;
      final newName = entry.value;
      if (!await programmeExists(oldName)) continue;
      await _db.exerciseDao.renameProgramme(oldName, newName);
      await _db.programmeDao.deleteByName(oldName);
      await _db.programmeDao.upsert(
        ProgrammesCompanion.insert(name: newName, importedAt: _nowIso()),
      );
      if (getProgrammeName() == oldName) {
        await setProgrammeName(newName);
      }
    }
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
