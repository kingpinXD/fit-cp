import 'dart:io';

import 'package:drift/native.dart';
import 'package:fit_cp/data/database/app_database.dart';
import 'package:fit_cp/data/models/import_result.dart';
import 'package:fit_cp/data/repositories/programme_repository.dart';
import 'package:fit_cp/data/sync/firebase_sync_manager.dart';
import 'package:fit_cp/features/programme/programme_notifier.dart';
import 'package:fit_cp/features/programme/programme_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String sampleJson = '''
{
  "weeks": [
    {"week": 1, "days": [
      {"day": "Day A", "exercises": [
        {"name": "Squat", "sets": 3, "reps": "5", "rpe": "8-9", "order": 0},
        {"name": "Bench", "sets": 3, "reps": "8", "rpe": "8", "order": 1}
      ]},
      {"day": "Day B", "exercises": [
        {"name": "Deadlift", "sets": 1, "reps": "5", "rpe": "9", "order": 0}
      ]}
    ]},
    {"week": 2, "days": [
      {"day": "Day A", "exercises": [
        {"name": "Squat", "sets": 3, "reps": "5", "rpe": "9", "order": 0}
      ]}
    ]}
  ]
}
''';

const String sampleJsonTwo = '''
{
  "weeks": [
    {"week": 1, "days": [
      {"day": "Push", "exercises": [
        {"name": "OHP", "sets": 3, "reps": "5", "rpe": "8", "order": 0}
      ]}
    ]}
  ]
}
''';

class _FakeFirebaseSyncManager extends FirebaseSyncManager {
  _FakeFirebaseSyncManager(this._signedIn);
  final bool _signedIn;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Future<bool> exportProgramme(String name, String id, String json) async =>
      _signedIn;
}

/// Read the first emission from a stream provider. Subscribes via
/// `container.listen` to keep the provider alive while the future settles —
/// `.future` alone may stall because the stream-provider element disposes
/// before any emission lands.
Future<T> firstStream<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = container.listen<AsyncValue<T>>(provider, (_, _) {});
  try {
    while (sub.read() is AsyncLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return sub.read().value as T;
  } finally {
    sub.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<ProviderContainer> makeContainer({bool firebaseSignedIn = false}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());

    Future<String> assetLoader(String path) async {
      final filename = path.split('/').last;
      return File('test/resources/$filename').readAsString();
    }

    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      programmeRepositoryProvider.overrideWith(
        (ref) => ProgrammeRepository(
          db: ref.watch(appDatabaseProvider),
          prefs: ref.watch(sharedPreferencesProvider),
          assetLoader: assetLoader,
        ),
      ),
      firebaseSyncManagerProvider
          .overrideWithValue(_FakeFirebaseSyncManager(firebaseSignedIn)),
    ]);
    return c;
  }

  setUp(() async {
    container = await makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Initial state', () {
    test('no programme means hasProgramme false', () async {
      // Trigger the notifier so its build() runs.
      container.read(programmeNotifierProvider);
      // Drain microtasks but skip the bundled-asset preload so the test
      // stays focused on the empty path.
      expect(container.read(programmeNameProvider), '');
    });
  });

  group('Import', () {
    test('importProgramme - sets programme name and exposes weeks', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      final result = await notifier.importProgramme(sampleJson, 'test_prog');
      expect(result, ImportResult.imported);
      expect(container.read(programmeNameProvider), 'test_prog');

      final weeks = await firstStream(container, weeksProvider);
      expect(weeks, [1, 2]);
    });

    test('importProgramme twice with same name - second is SWITCHED',
        () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      final first = await notifier.importProgramme(sampleJson, 'test_prog');
      final second = await notifier.importProgramme(sampleJson, 'test_prog');
      expect(first, ImportResult.imported);
      expect(second, ImportResult.switched);
    });

    test('malformed JSON - returns null and leaves state untouched',
        () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      final result = await notifier.importProgramme('{not json', 'broken');
      expect(result, isNull);
      expect(container.read(programmeNameProvider), '');
    });
  });

  group('Reactive wiring', () {
    test('selecting week exposes its days', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');

      var days = await firstStream(container, daysProvider(1));
      expect(days, ['Day A', 'Day B']);

      days = await firstStream(container, daysProvider(2));
      expect(days, ['Day A']);
    });

    test('selecting week and day exposes exercises in order', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');

      final exercises =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));
      expect(exercises.map((e) => e.exerciseName).toList(),
          ['Squat', 'Bench']);
      expect(exercises.map((e) => e.orderIndex).toList(), [0, 1]);
    });
  });

  group('markDone / markSkipped', () {
    test('markDone writes a DONE log with provided weight, equipment, rpe',
        () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');
      final exs =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));
      await notifier.markDone(
        exs.first,
        '100',
        'Barbell,Each Side',
        'felt good',
        '9',
      );

      final log = await firstStream(
          container, selectedExerciseLogProvider(exs.first.id));
      expect(log, isNotNull);
      expect(log!.userWeight, '100');
      expect(log.equipmentType, 'Barbell,Each Side');
      expect(log.userComments, 'felt good');
      expect(log.observedRpe, '9');
      expect(log.status, 'DONE');
    });

    test('markDone with blank rpe falls back to exercise default rpe',
        () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');
      final exs =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));
      final squat =
          exs.firstWhere((e) => e.exerciseName == 'Squat');
      await notifier.markDone(squat, '120', '', '', '');

      final log =
          await firstStream(container, selectedExerciseLogProvider(squat.id));
      expect(log!.observedRpe, '8-9');
    });

    test('markDone twice replaces existing log', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');
      final exs =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));

      await notifier.markDone(exs.first, '100', '', '', '8');
      await notifier.markDone(exs.first, '110', '', '', '9');

      final log = await firstStream(
          container, selectedExerciseLogProvider(exs.first.id));
      expect(log!.userWeight, '110');
      expect(log.observedRpe, '9');
    });

    test('markSkipped writes a SKIPPED log with empty fields', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');
      final exs =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));
      await notifier.markSkipped(exs.first);

      final log = await firstStream(
          container, selectedExerciseLogProvider(exs.first.id));
      expect(log!.status, 'SKIPPED');
      expect(log.userWeight, '');
      expect(log.observedRpe, '');
    });
  });

  group('switchProgramme / deleteProgramme', () {
    test('switchProgramme updates active programme name', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'first');
      await notifier.importProgramme(sampleJsonTwo, 'second');

      await notifier.switchProgramme('first');
      expect(container.read(programmeNameProvider), 'first');
    });

    test('deleteProgramme clears name and resets selection state',
        () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');

      notifier.selectWeek(1);
      notifier.selectDay('Day A');
      final exs =
          await firstStream(container, exercisesProvider(const WeekDay(1, 'Day A')));
      notifier.selectExercise(exs.first);
      notifier.setShowTable(true);
      notifier.setShowHistory(true);

      await notifier.deleteProgramme();

      expect(container.read(programmeNameProvider), '');
      final state = container.read(programmeNotifierProvider);
      expect(state.selectedWeek, isNull);
      expect(state.selectedDay, isNull);
      expect(state.selectedExercise, isNull);
      expect(state.showTable, isFalse);
      expect(state.showHistory, isFalse);
    });
  });

  group('exportProgramme', () {
    test('returns firebaseOk = false when not signed in', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');

      final outcome = await notifier.exportProgramme('user-id');
      expect(outcome.firebaseOk, isFalse);
      expect(outcome.json, isNotNull);
    });

    test('returns firebaseOk = true when signed-in fake injected', () async {
      container.dispose();
      container = await makeContainer(firebaseSignedIn: true);
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'test_prog');

      final outcome = await notifier.exportProgramme('user-id');
      expect(outcome.firebaseOk, isTrue);
    });
  });

  group('availableProgrammes', () {
    test('lists every imported programme', () async {
      final notifier = container.read(programmeNotifierProvider.notifier);
      await notifier.importProgramme(sampleJson, 'first');
      await notifier.importProgramme(sampleJsonTwo, 'second');

      final names =
          (await firstStream(container, availableProgrammesProvider))
              .map((p) => p.name);
      expect(names, contains('first'));
      expect(names, contains('second'));
    });
  });
}
