import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fit_cp/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DAO roundtrip', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insert + query roundtrip preserves all fields', () async {
      await db.exerciseDao.insertAll([
        ExercisesCompanion.insert(
          weekNumber: 1,
          dayName: 'Full Body A',
          exerciseName: 'Flat DB Press',
          sets: 3,
          reps: '8-10',
          orderIndex: 1,
          rpe: const Value('8'),
          notes: const Value('focus on stretch'),
          warmupSets: const Value('2'),
          rest: const Value('~3 min'),
          sub1: const Value('Machine Press'),
          sub2: const Value('Dip'),
          videoUrl: const Value('https://youtu.be/x'),
          sub1VideoUrl: const Value('https://youtu.be/y'),
          sub2VideoUrl: const Value('https://youtu.be/z'),
          programmeName: const Value('essentials_2x'),
        ),
      ]);

      final rows = await db.exerciseDao
          .watchExercises('essentials_2x', 1, 'Full Body A')
          .first;
      expect(rows.length, 1);
      final r = rows.single;
      expect(r.exerciseName, 'Flat DB Press');
      expect(r.sets, 3);
      expect(r.reps, '8-10');
      expect(r.orderIndex, 1);
      expect(r.rpe, '8');
      expect(r.notes, 'focus on stretch');
      expect(r.warmupSets, '2');
      expect(r.rest, '~3 min');
      expect(r.sub1, 'Machine Press');
      expect(r.sub2, 'Dip');
      expect(r.videoUrl, 'https://youtu.be/x');
      expect(r.sub1VideoUrl, 'https://youtu.be/y');
      expect(r.sub2VideoUrl, 'https://youtu.be/z');
      expect(r.programmeName, 'essentials_2x');
    });

    test('completed days reflect logs by exercise count', () async {
      await db.exerciseDao.insertAll([
        ExercisesCompanion.insert(
          weekNumber: 1,
          dayName: 'A',
          exerciseName: 'X',
          sets: 1,
          reps: '5',
          orderIndex: 1,
          programmeName: const Value('p'),
        ),
        ExercisesCompanion.insert(
          weekNumber: 1,
          dayName: 'A',
          exerciseName: 'Y',
          sets: 1,
          reps: '5',
          orderIndex: 2,
          programmeName: const Value('p'),
        ),
      ]);

      final completedBefore =
          await db.exerciseDao.watchCompletedDays('p', 1).first;
      expect(completedBefore, isEmpty);

      final all = await db.exerciseDao.getAllExercises('p');
      for (final ex in all) {
        await db.exerciseLogDao.upsert(
          ExerciseLogsCompanion.insert(
            exerciseId: ex.id,
            userWeight: '100',
            userComments: '',
            observedRpe: '8',
            status: 'DONE',
          ),
        );
      }

      final completedAfter =
          await db.exerciseDao.watchCompletedDays('p', 1).first;
      expect(completedAfter, ['A']);
    });
  });
}
