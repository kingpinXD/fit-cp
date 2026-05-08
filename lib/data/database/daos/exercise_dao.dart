import 'package:drift/drift.dart';

import '../../models/day_info.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [Exercises])
class ExerciseDao extends DatabaseAccessor<AppDatabase> with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Stream<List<ExerciseRow>> watchExercises(
    String programmeName,
    int weekNumber,
    String dayName,
  ) {
    return (select(exercises)
          ..where((e) =>
              e.programmeName.equals(programmeName) &
              e.weekNumber.equals(weekNumber) &
              e.dayName.equals(dayName))
          ..orderBy([(e) => OrderingTerm(expression: e.orderIndex)]))
        .watch();
  }

  Stream<List<int>> watchDistinctWeeks(String programmeName) {
    final query = selectOnly(exercises, distinct: true)
      ..addColumns([exercises.weekNumber])
      ..where(exercises.programmeName.equals(programmeName))
      ..orderBy([OrderingTerm(expression: exercises.weekNumber)]);
    return query
        .map((row) => row.read(exercises.weekNumber)!)
        .watch();
  }

  Stream<List<String>> watchDistinctDays(
    String programmeName,
    int weekNumber,
  ) {
    final query = selectOnly(exercises)
      ..addColumns([exercises.dayName, exercises.id.min()])
      ..where(exercises.programmeName.equals(programmeName) &
          exercises.weekNumber.equals(weekNumber))
      ..groupBy([exercises.dayName])
      ..orderBy([OrderingTerm(expression: exercises.id.min())]);
    return query
        .map((row) => row.read(exercises.dayName)!)
        .watch();
  }

  Future<void> insertAll(List<Insertable<ExerciseRow>> rows) async {
    await batch((b) => b.insertAll(exercises, rows));
  }

  Future<int> count() async {
    final query = selectOnly(exercises)..addColumns([exercises.id.count()]);
    final row = await query.getSingle();
    return row.read(exercises.id.count()) ?? 0;
  }

  Stream<int> watchCountByProgramme(String programmeName) {
    final query = selectOnly(exercises)
      ..addColumns([exercises.id.count()])
      ..where(exercises.programmeName.equals(programmeName));
    return query
        .map((row) => row.read(exercises.id.count()) ?? 0)
        .watchSingle();
  }

  Future<int> countByProgramme(String programmeName) async {
    final query = selectOnly(exercises)
      ..addColumns([exercises.id.count()])
      ..where(exercises.programmeName.equals(programmeName));
    final row = await query.getSingle();
    return row.read(exercises.id.count()) ?? 0;
  }

  Future<List<ExerciseRow>> getAllExercises(String programmeName) {
    return (select(exercises)
          ..where((e) => e.programmeName.equals(programmeName))
          ..orderBy([
            (e) => OrderingTerm(expression: e.weekNumber),
            (e) => OrderingTerm(expression: e.id),
          ]))
        .get();
  }

  Stream<List<String>> watchCompletedDays(String programmeName, int weekNumber) {
    return customSelect(
      'SELECT e.dayName FROM exercises e '
      'WHERE e.programmeName = ?1 AND e.weekNumber = ?2 '
      'GROUP BY e.dayName '
      'HAVING COUNT(e.id) = ('
      '  SELECT COUNT(el.id) FROM exercise_logs el '
      '  INNER JOIN exercises e2 ON el.exerciseId = e2.id '
      '  WHERE e2.programmeName = ?1 AND e2.weekNumber = ?2 AND e2.dayName = e.dayName'
      ') '
      'ORDER BY MIN(e.id)',
      variables: [Variable.withString(programmeName), Variable.withInt(weekNumber)],
      readsFrom: {exercises, attachedDatabase.exerciseLogs},
    ).watch().map((rows) => rows.map((r) => r.read<String>('dayName')).toList());
  }

  Stream<List<int>> watchCompletedWeeks(String programmeName) {
    return customSelect(
      'SELECT e.weekNumber FROM exercises e '
      'WHERE e.programmeName = ?1 '
      'GROUP BY e.weekNumber '
      'HAVING COUNT(e.id) = ('
      '  SELECT COUNT(el.id) FROM exercise_logs el '
      '  INNER JOIN exercises e2 ON el.exerciseId = e2.id '
      '  WHERE e2.programmeName = ?1 AND e2.weekNumber = e.weekNumber'
      ') '
      'ORDER BY e.weekNumber',
      variables: [Variable.withString(programmeName)],
      readsFrom: {exercises, attachedDatabase.exerciseLogs},
    ).watch().map((rows) => rows.map((r) => r.read<int>('weekNumber')).toList());
  }

  Future<DayInfo?> getFirstIncompleteDay(String programmeName) async {
    final rows = await customSelect(
      'SELECT e.weekNumber, e.dayName FROM exercises e '
      'WHERE e.programmeName = ?1 '
      'GROUP BY e.weekNumber, e.dayName '
      'HAVING COUNT(e.id) > ('
      '  SELECT COUNT(el.id) FROM exercise_logs el '
      '  INNER JOIN exercises e2 ON el.exerciseId = e2.id '
      '  WHERE e2.programmeName = ?1 AND e2.weekNumber = e.weekNumber AND e2.dayName = e.dayName'
      ') '
      'ORDER BY e.weekNumber, MIN(e.id) '
      'LIMIT 1',
      variables: [Variable.withString(programmeName)],
      readsFrom: {exercises, attachedDatabase.exerciseLogs},
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DayInfo(
      weekNumber: row.read<int>('weekNumber'),
      dayName: row.read<String>('dayName'),
    );
  }

  Future<void> deleteAll() async {
    await delete(exercises).go();
  }

  Future<void> deleteByProgramme(String programmeName) async {
    await (delete(exercises)..where((e) => e.programmeName.equals(programmeName)))
        .go();
  }

  Future<void> renameProgramme(String oldName, String newName) async {
    await (update(exercises)..where((e) => e.programmeName.equals(oldName)))
        .write(ExercisesCompanion(programmeName: Value(newName)));
  }

  Future<void> deduplicateByProgramme(String programmeName, int keepCount) async {
    await customStatement(
      'DELETE FROM exercises WHERE programmeName = ? '
      'AND id NOT IN (SELECT id FROM exercises WHERE programmeName = ? '
      'ORDER BY id LIMIT ?)',
      [programmeName, programmeName, keepCount],
    );
  }
}
