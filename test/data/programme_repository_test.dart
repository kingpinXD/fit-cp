import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fit_cp/data/database/app_database.dart';
import 'package:fit_cp/data/models/import_result.dart';
import 'package:fit_cp/data/repositories/programme_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String sampleJson = '''
{
  "weeks": [
    {
      "week": 1,
      "days": [
        {
          "day": "Day A",
          "exercises": [
            {"name": "Squat", "sets": 3, "reps": "5", "rpe": "8-9", "order": 0},
            {"name": "Bench", "sets": 3, "reps": "8", "rpe": "8", "order": 1}
          ]
        },
        {
          "day": "Day B",
          "exercises": [
            {"name": "Deadlift", "sets": 1, "reps": "5", "rpe": "9", "order": 0}
          ]
        }
      ]
    },
    {
      "week": 2,
      "days": [
        {
          "day": "Day A",
          "exercises": [
            {"name": "Squat", "sets": 3, "reps": "5", "rpe": "9", "order": 0},
            {"name": "Bench", "sets": 3, "reps": "8", "rpe": "8", "order": 1}
          ]
        },
        {
          "day": "Day B",
          "exercises": [
            {"name": "Deadlift", "sets": 1, "reps": "5", "rpe": "9", "order": 0}
          ]
        }
      ]
    }
  ]
}
''';

const String sampleJsonTwo = '''
{
  "weeks": [
    {
      "week": 1,
      "days": [
        {
          "day": "Push",
          "exercises": [
            {"name": "OHP", "sets": 3, "reps": "5", "rpe": "8", "order": 0}
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late ProgrammeRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());

    Future<String> assetLoader(String path) async {
      final filename = path.split('/').last;
      // Used by preloadProgrammes — read the bundled fixtures from disk.
      return File('test/resources/$filename').readAsString();
    }

    repo = ProgrammeRepository(
      db: db,
      prefs: prefs,
      assetLoader: assetLoader,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Programme name persistence', () {
    test('setProgrammeName then getProgrammeName round-trips', () async {
      expect(repo.getProgrammeName(), '');
      await repo.setProgrammeName('my_prog');
      expect(repo.getProgrammeName(), 'my_prog');
    });
  });

  group('importProgrammeFromJson', () {
    test('inserts exercises and registers programme', () async {
      final result = await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      expect(result, ImportResult.imported);
      expect(repo.getProgrammeName(), 'test_prog');
      expect(await repo.programmeExists('test_prog'), isTrue);
    });

    test('second import with same name returns SWITCHED', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      await repo.setProgrammeName('');

      final second = await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      expect(second, ImportResult.switched);
      expect(repo.getProgrammeName(), 'test_prog');
    });

    test('exercises preserve order, week and day', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final all = await db.exerciseDao.getAllExercises('test_prog');
      final w1A = all
          .where((e) => e.weekNumber == 1 && e.dayName == 'Day A')
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(w1A.map((e) => e.exerciseName).toList(), ['Squat', 'Bench']);
      expect(
        w1A.firstWhere((e) => e.exerciseName == 'Squat').rpe,
        '8-9',
      );
    });

    test('distinct programmes coexist', () async {
      await repo.importProgrammeFromJson(sampleJson, 'first');
      await repo.importProgrammeFromJson(sampleJsonTwo, 'second');

      expect(await repo.programmeExists('first'), isTrue);
      expect(await repo.programmeExists('second'), isTrue);
      expect(repo.getProgrammeName(), 'second');

      final firstCount = await db.exerciseDao.countByProgramme('first');
      final secondCount = await db.exerciseDao.countByProgramme('second');
      expect(firstCount, greaterThan(0));
      expect(secondCount, greaterThan(0));
    });
  });

  group('Delete', () {
    test('removes exercises, logs and registry entry', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final firstEx = (await db.exerciseDao.getAllExercises('test_prog')).first;
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: firstEx.id,
        userWeight: '100',
        equipmentType: const Value('Barbell'),
        userComments: 'ok',
        observedRpe: '8',
        status: 'DONE',
      ));

      await repo.deleteProgramme();

      expect(repo.getProgrammeName(), '');
      expect(await repo.programmeExists('test_prog'), isFalse);
      expect(await db.exerciseDao.countByProgramme('test_prog'), 0);
      expect(await db.exerciseLogDao.getLogSync(firstEx.id), isNull);
    });

    test('deleteProgramme with no active programme is a no-op', () async {
      await repo.deleteProgramme();
      expect(repo.getProgrammeName(), '');
    });
  });

  group('Log save / get', () {
    test('saveLog and getLogSync round-trip', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final ex = (await db.exerciseDao.getAllExercises('test_prog')).first;

      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: ex.id,
        userWeight: '100',
        equipmentType: const Value('Barbell'),
        userComments: 'wk1',
        observedRpe: '9',
        status: 'DONE',
      ));

      final log = await repo.getLogSync(ex.id);
      expect(log, isNotNull);
      expect(log!.userWeight, '100');
      expect(log.status, 'DONE');
    });

    test('saveLog twice replaces existing log', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final ex = (await db.exerciseDao.getAllExercises('test_prog')).first;

      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: ex.id,
        userWeight: '100',
        userComments: '',
        observedRpe: '8',
        status: 'DONE',
      ));
      final firstId = (await repo.getLogSync(ex.id))!.id;
      await repo.saveLog(ExerciseLogsCompanion(
        id: Value(firstId),
        exerciseId: Value(ex.id),
        userWeight: const Value('110'),
        userComments: const Value(''),
        observedRpe: const Value('9'),
        status: const Value('DONE'),
      ));

      final log = (await repo.getLogSync(ex.id))!;
      expect(log.userWeight, '110');
      expect(log.observedRpe, '9');
    });
  });

  group('Reactive queries', () {
    test('hasProgrammeByName flips true after import', () async {
      expect(await repo.hasProgrammeByName('test_prog').first, isFalse);
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      expect(await repo.hasProgrammeByName('test_prog').first, isTrue);
    });

    test('getDistinctWeeksByName returns sorted weeks', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      expect(await repo.getDistinctWeeksByName('test_prog').first, [1, 2]);
    });

    test('getExercises filters by active programme name', () async {
      await repo.importProgrammeFromJson(sampleJson, 'first');
      await repo.importProgrammeFromJson(sampleJsonTwo, 'second');
      await repo.setProgrammeName('first');

      final w1A = await repo.getExercises(1, 'Day A').first;
      expect(w1A.map((e) => e.exerciseName).toList(), ['Squat', 'Bench']);

      await repo.setProgrammeName('second');
      final push = await repo.getExercises(1, 'Push').first;
      expect(push.map((e) => e.exerciseName).toList(), ['OHP']);
    });
  });

  group('Completion logic', () {
    test('getCompletedDays surfaces day only when every exercise is logged',
        () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final w1A = (await db.exerciseDao.getAllExercises('test_prog'))
          .where((e) => e.weekNumber == 1 && e.dayName == 'Day A')
          .toList();

      expect(await repo.getCompletedDays(1).first, isEmpty);

      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: w1A[0].id,
        userWeight: '',
        userComments: '',
        observedRpe: '',
        status: 'DONE',
      ));
      expect(await repo.getCompletedDays(1).first, isEmpty);

      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: w1A[1].id,
        userWeight: '',
        userComments: '',
        observedRpe: '',
        status: 'DONE',
      ));
      expect(await repo.getCompletedDays(1).first, ['Day A']);
    });

    test('getCompletedWeeks surfaces week only when all days are complete',
        () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final w1 = (await db.exerciseDao.getAllExercises('test_prog'))
          .where((e) => e.weekNumber == 1);

      for (final ex in w1.where((e) => e.dayName == 'Day A')) {
        await repo.saveLog(ExerciseLogsCompanion.insert(
          exerciseId: ex.id,
          userWeight: '',
          userComments: '',
          observedRpe: '',
          status: 'DONE',
        ));
      }
      expect(await repo.getCompletedWeeks().first, isEmpty);

      for (final ex in w1.where((e) => e.dayName == 'Day B')) {
        await repo.saveLog(ExerciseLogsCompanion.insert(
          exerciseId: ex.id,
          userWeight: '',
          userComments: '',
          observedRpe: '',
          status: 'DONE',
        ));
      }
      expect(await repo.getCompletedWeeks().first, [1]);
    });

    test('getFirstIncompleteDay returns earliest unfinished day', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');

      var first = await repo.getFirstIncompleteDay();
      expect(first, isNotNull);
      expect(first!.weekNumber, 1);
      expect(first.dayName, 'Day A');

      final w1 = (await db.exerciseDao.getAllExercises('test_prog'))
          .where((e) => e.weekNumber == 1);
      for (final ex in w1) {
        await repo.saveLog(ExerciseLogsCompanion.insert(
          exerciseId: ex.id,
          userWeight: '',
          userComments: '',
          observedRpe: '',
          status: 'DONE',
        ));
      }
      final next = await repo.getFirstIncompleteDay();
      expect(next!.weekNumber, 2);
      expect(next.dayName, 'Day A');
    });

    test('getFirstIncompleteDay returns null when entire programme complete',
        () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      for (final ex in await db.exerciseDao.getAllExercises('test_prog')) {
        await repo.saveLog(ExerciseLogsCompanion.insert(
          exerciseId: ex.id,
          userWeight: '',
          userComments: '',
          observedRpe: '',
          status: 'DONE',
        ));
      }
      expect(await repo.getFirstIncompleteDay(), isNull);
    });

    test(
        'getFirstIncompleteDay skips fully logged day and returns next exercise-only day',
        () async {
      const json = '''
      {
        "weeks": [
          {"week": 1, "days": [
            {"day": "W1D1", "exercises": [
              {"name": "A1", "sets": 1, "reps": "5", "order": 0}
            ]},
            {"day": "W1D3", "exercises": [
              {"name": "C1", "sets": 1, "reps": "5", "order": 0}
            ]}
          ]},
          {"week": 2, "days": [
            {"day": "W2D1", "exercises": [
              {"name": "X1", "sets": 1, "reps": "5", "order": 0}
            ]}
          ]}
        ]
      }
      ''';
      await repo.importProgrammeFromJson(json, 'sparse');
      final all = await db.exerciseDao.getAllExercises('sparse');
      final w1d1 = all.firstWhere(
          (e) => e.weekNumber == 1 && e.dayName == 'W1D1');
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: w1d1.id,
        userWeight: '',
        userComments: '',
        observedRpe: '',
        status: 'DONE',
      ));

      final next = await repo.getFirstIncompleteDay();
      expect(next!.weekNumber, 1);
      expect(next.dayName, 'W1D3');
    });
  });

  group('History', () {
    test('returns prior-week logs sorted descending', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final w1Squat = (await db.exerciseDao.getAllExercises('test_prog'))
          .firstWhere((e) => e.weekNumber == 1 && e.exerciseName == 'Squat');
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: w1Squat.id,
        userWeight: '100',
        userComments: '',
        observedRpe: '8',
        status: 'DONE',
      ));

      final history = await repo.getHistory('Squat', 2).first;
      expect(history.length, 1);
      expect(history.first.weekNumber, 1);
      expect(history.first.userWeight, '100');
    });

    test('empty when current week is 1', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final w1Squat = (await db.exerciseDao.getAllExercises('test_prog'))
          .firstWhere((e) => e.weekNumber == 1 && e.exerciseName == 'Squat');
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: w1Squat.id,
        userWeight: '100',
        userComments: '',
        observedRpe: '8',
        status: 'DONE',
      ));

      final history = await repo.getHistory('Squat', 1).first;
      expect(history, isEmpty);
    });
  });

  group('Export', () {
    test('produces parseable JSON with weeks, days and logs', () async {
      await repo.importProgrammeFromJson(sampleJson, 'test_prog');
      final ex = (await db.exerciseDao.getAllExercises('test_prog')).first;
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: ex.id,
        userWeight: '100',
        equipmentType: const Value('Barbell'),
        userComments: 'wk1',
        observedRpe: '8',
        status: 'DONE',
      ));

      final json = await repo.buildExportJson('test_prog', 'user-id');
      final root = jsonDecode(json) as Map<String, dynamic>;
      expect(root['programmeName'], 'test_prog');
      expect(root['identifier'], 'user-id');

      final weeks = (root['programme'] as Map)['weeks'] as List;
      expect(weeks.length, 2);

      final logs = root['logs'] as List;
      expect(logs.length, 1);
      expect((logs.first as Map)['userWeight'], '100');
      expect((logs.first as Map)['status'], 'DONE');
    });

    test('blank programmeName falls back to active prefs', () async {
      await repo.importProgrammeFromJson(sampleJson, 'active_prog');
      await repo.setProgrammeName('active_prog');

      final json = await repo.buildExportJson('', 'id');
      final root = jsonDecode(json) as Map<String, dynamic>;
      expect(root['programmeName'], 'active_prog');
    });

    test('full export shape has expected fields per exercise and log',
        () async {
      const json = '''
      {
        "weeks": [
          {"week": 1, "days": [
            {"day": "Day A", "exercises": [
              {"name": "Squat", "sets": 3, "reps": "5", "rpe": "8", "rest": "120s",
               "warmupSets": "2", "notes": "n1", "order": 0,
               "sub1": "Goblet Squat", "sub2": "Leg Press"},
              {"name": "Bench", "sets": 3, "reps": "8", "rpe": "9", "rest": "90s",
               "warmupSets": "1", "notes": "n2", "order": 1,
               "sub1": "DB Press", "sub2": ""}
            ]}
          ]}
        ]
      }
      ''';
      await repo.importProgrammeFromJson(json, 'test_prog');
      final all = await db.exerciseDao.getAllExercises('test_prog');
      await repo.saveLog(ExerciseLogsCompanion.insert(
        exerciseId: all[0].id,
        userWeight: '100',
        equipmentType: const Value('Barbell'),
        userComments: 'first',
        observedRpe: '8',
        status: 'DONE',
      ));

      final out = await repo.buildExportJson('test_prog', 'user@x');
      final root = jsonDecode(out) as Map<String, dynamic>;
      expect(root['programmeName'], 'test_prog');
      expect(root['identifier'], 'user@x');
      DateTime.parse(root['exportDate'] as String);

      final weeks = (root['programme'] as Map)['weeks'] as List;
      expect(weeks.length, 1);
      final exercises =
          ((weeks.first as Map)['days'] as List).first as Map;
      final exerciseList = exercises['exercises'] as List;
      const expectedFields = [
        'name', 'sets', 'reps', 'rpe', 'rest',
        'warmupSets', 'notes', 'order', 'sub1', 'sub2',
      ];
      for (final ex in exerciseList) {
        for (final key in expectedFields) {
          expect((ex as Map).containsKey(key), isTrue,
              reason: 'exercise should have $key');
        }
      }

      final logs = root['logs'] as List;
      expect(logs.length, 1);
      const expectedLogFields = [
        'exerciseName', 'weekNumber', 'dayName', 'userWeight',
        'equipmentType', 'observedRpe', 'userComments', 'status',
      ];
      for (final key in expectedLogFields) {
        expect((logs.first as Map).containsKey(key), isTrue);
      }
    });
  });

  group('preloadProgrammes', () {
    test('second call is idempotent', () async {
      await repo.preloadProgrammes();
      final counts1 = <String, int>{};
      for (final n in ProgrammeRepository.bundledProgrammes.keys) {
        counts1[n] = await db.exerciseDao.countByProgramme(n);
        expect(counts1[n], greaterThan(0));
      }

      await repo.preloadProgrammes();
      final counts2 = <String, int>{};
      for (final n in ProgrammeRepository.bundledProgrammes.keys) {
        counts2[n] = await db.exerciseDao.countByProgramme(n);
      }

      expect(counts2, counts1);
    });

    test('2x trims excess exercises down to 180', () async {
      await _seedDuplicates(db, 'essentials_2x', 200);
      await repo.preloadProgrammes();
      expect(await db.exerciseDao.countByProgramme('essentials_2x'), 180);
    });

    test('3x trims excess exercises down to 240', () async {
      await _seedDuplicates(db, 'essentials_3x', 260);
      await repo.preloadProgrammes();
      expect(await db.exerciseDao.countByProgramme('essentials_3x'), 240);
    });

    test('4x trims excess exercises down to 288', () async {
      await _seedDuplicates(db, 'essentials_4x', 300);
      await repo.preloadProgrammes();
      expect(await db.exerciseDao.countByProgramme('essentials_4x'), 288);
    });

    test('5x trims excess exercises down to 324', () async {
      await _seedDuplicates(db, 'essentials_5x', 350);
      await repo.preloadProgrammes();
      expect(await db.exerciseDao.countByProgramme('essentials_5x'), 324);
    });

    test('repair4xDayNames rewrites programme when week 1 has < 4 day names',
        () async {
      final rows = <ExercisesCompanion>[];
      for (var weekIdx = 1; weekIdx <= 20; weekIdx++) {
        for (final day in ['Upper', 'Lower']) {
          for (var ord = 1; ord <= 5; ord++) {
            rows.add(ExercisesCompanion.insert(
              weekNumber: weekIdx,
              dayName: day,
              exerciseName: 'ex_$ord',
              sets: 3,
              reps: '5',
              orderIndex: ord,
              programmeName: const Value('essentials_4x'),
            ));
          }
        }
      }
      await db.exerciseDao.insertAll(rows);
      await db.programmeDao.upsert(ProgrammesCompanion.insert(
        name: 'essentials_4x',
        importedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      final before = (await db.exerciseDao.getAllExercises('essentials_4x'))
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(before.length, 2);

      await repo.preloadProgrammes();

      final after = (await db.exerciseDao.getAllExercises('essentials_4x'))
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(after.length, 4);
      expect(after.contains('Upper #2'), isTrue);
    });
  });

  group('cleanupLegacyNames', () {
    test('underscore legacy renamed to canonical', () async {
      const legacy = 'the_essentials_2x';
      const newName = 'essentials_2x';
      await _seedDuplicates(db, legacy, 5);
      await db.programmeDao.upsert(ProgrammesCompanion.insert(
        name: legacy,
        importedAt: DateTime.now().toUtc().toIso8601String(),
      ));
      await repo.setProgrammeName(legacy);

      await repo.preloadProgrammes();

      expect(await db.programmeDao.exists(legacy), isFalse);
      expect(await db.programmeDao.exists(newName), isTrue);
      expect(await db.exerciseDao.countByProgramme(legacy), 0);
      expect(await db.exerciseDao.countByProgramme(newName), 5);
      expect(repo.getProgrammeName(), newName);
    });

    test('space-cased legacy renamed to canonical', () async {
      const legacy = 'Essentials 5x';
      const newName = 'essentials_5x';
      await _seedDuplicates(db, legacy, 5);
      await db.programmeDao.upsert(ProgrammesCompanion.insert(
        name: legacy,
        importedAt: DateTime.now().toUtc().toIso8601String(),
      ));
      await repo.setProgrammeName(legacy);

      await repo.preloadProgrammes();

      expect(await db.programmeDao.exists(legacy), isFalse);
      expect(await db.programmeDao.exists(newName), isTrue);
      expect(await db.exerciseDao.countByProgramme(legacy), 0);
      expect(repo.getProgrammeName(), newName);
    });

    test('prefs untouched when active programme differs', () async {
      await _seedDuplicates(db, 'the_essentials_3x', 5);
      await db.programmeDao.upsert(ProgrammesCompanion.insert(
        name: 'the_essentials_3x',
        importedAt: DateTime.now().toUtc().toIso8601String(),
      ));
      await repo.setProgrammeName('something_else');

      await repo.preloadProgrammes();

      expect(repo.getProgrammeName(), 'something_else');
    });
  });

  group('importProgrammeFromXlsx', () {
    test('happy path inserts exercises under given name', () async {
      final bytes = File('test/resources/programmes/essentials_2x.xlsx')
          .readAsBytesSync();
      final result = await repo.importProgrammeFromXlsx(bytes, 'from_xlsx');

      expect(result, ImportResult.imported);
      expect(repo.getProgrammeName(), 'from_xlsx');
      expect(await db.exerciseDao.countByProgramme('from_xlsx'), greaterThan(0));
      final w1Days = (await db.exerciseDao.getAllExercises('from_xlsx'))
          .where((e) => e.weekNumber == 1)
          .map((e) => e.dayName)
          .toSet();
      expect(w1Days.contains('Full Body A'), isTrue);
      expect(w1Days.contains('Full Body B'), isTrue);
    });

    test('re-import with same name returns SWITCHED', () async {
      final bytes = File('test/resources/programmes/essentials_2x.xlsx')
          .readAsBytesSync();
      await repo.importProgrammeFromXlsx(bytes, 'from_xlsx');
      await repo.setProgrammeName('');

      final second = await repo.importProgrammeFromXlsx(bytes, 'from_xlsx');
      expect(second, ImportResult.switched);
      expect(repo.getProgrammeName(), 'from_xlsx');
    });
  });

  group('Available programmes', () {
    test('lists imported programmes', () async {
      await repo.importProgrammeFromJson(sampleJson, 'first');
      await repo.importProgrammeFromJson(sampleJsonTwo, 'second');

      final names = (await repo.getAvailableProgrammes().first)
          .map((p) => p.name)
          .toList();
      expect(names.contains('first'), isTrue);
      expect(names.contains('second'), isTrue);
    });
  });
}

Future<void> _seedDuplicates(
  AppDatabase db,
  String programmeName,
  int count,
) async {
  final rows = List.generate(
    count,
    (i) => ExercisesCompanion.insert(
      weekNumber: 1,
      dayName: 'D',
      exerciseName: 'ex_${i + 1}',
      sets: 1,
      reps: '5',
      orderIndex: i + 1,
      programmeName: Value(programmeName),
    ),
  );
  await db.exerciseDao.insertAll(rows);
}
