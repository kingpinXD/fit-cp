import 'package:drift/drift.dart';

import '../../models/exercise_history_entry.dart';
import '../../models/export_log_entry.dart';
import '../app_database.dart';
import '../tables/exercise_logs_table.dart';

part 'exercise_log_dao.g.dart';

@DriftAccessor(tables: [ExerciseLogs])
class ExerciseLogDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseLogDaoMixin {
  ExerciseLogDao(super.db);

  Stream<ExerciseLogRow?> watchLog(int exerciseId) {
    return (select(exerciseLogs)
          ..where((e) => e.exerciseId.equals(exerciseId))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<ExerciseLogRow?> getLogSync(int exerciseId) {
    return (select(exerciseLogs)
          ..where((e) => e.exerciseId.equals(exerciseId))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<ExerciseLogRow>> watchLogsForDay(
    String programmeName,
    int weekNumber,
    String dayName,
  ) {
    return customSelect(
      'SELECT el.* FROM exercise_logs el '
      'INNER JOIN exercises e ON el.exerciseId = e.id '
      'WHERE e.programmeName = ?1 AND e.weekNumber = ?2 AND e.dayName = ?3',
      variables: [
        Variable.withString(programmeName),
        Variable.withInt(weekNumber),
        Variable.withString(dayName),
      ],
      readsFrom: {exerciseLogs, attachedDatabase.exercises},
    ).watch().map((rows) => rows.map(_toLogRow).toList());
  }

  Stream<List<ExerciseHistoryEntry>> watchHistory(
    String programmeName,
    String exerciseName,
    int currentWeek,
  ) {
    return customSelect(
      'SELECT e.weekNumber, el.userWeight, el.equipmentType, '
      'el.userComments, el.observedRpe, el.status '
      'FROM exercise_logs el '
      'INNER JOIN exercises e ON el.exerciseId = e.id '
      'WHERE e.programmeName = ?1 AND e.exerciseName = ?2 '
      'AND e.weekNumber < ?3 '
      'ORDER BY e.weekNumber DESC',
      variables: [
        Variable.withString(programmeName),
        Variable.withString(exerciseName),
        Variable.withInt(currentWeek),
      ],
      readsFrom: {exerciseLogs, attachedDatabase.exercises},
    ).watch().map(
          (rows) => rows
              .map(
                (r) => ExerciseHistoryEntry(
                  weekNumber: r.read<int>('weekNumber'),
                  userWeight: r.read<String>('userWeight'),
                  equipmentType: r.read<String>('equipmentType'),
                  userComments: r.read<String>('userComments'),
                  observedRpe: r.read<String>('observedRpe'),
                  status: r.read<String>('status'),
                ),
              )
              .toList(),
        );
  }

  Future<void> upsert(ExerciseLogsCompanion log) async {
    await into(exerciseLogs).insertOnConflictUpdate(log);
  }

  Future<List<ExportLogEntry>> getExportLogs(String programmeName) async {
    final rows = await customSelect(
      'SELECT e.exerciseName, e.weekNumber, e.dayName, '
      'el.userWeight, el.equipmentType, el.userComments, '
      'el.observedRpe, el.status '
      'FROM exercise_logs el '
      'INNER JOIN exercises e ON el.exerciseId = e.id '
      'WHERE e.programmeName = ?1 '
      'ORDER BY e.weekNumber, e.id',
      variables: [Variable.withString(programmeName)],
      readsFrom: {exerciseLogs, attachedDatabase.exercises},
    ).get();
    return rows
        .map(
          (r) => ExportLogEntry(
            exerciseName: r.read<String>('exerciseName'),
            weekNumber: r.read<int>('weekNumber'),
            dayName: r.read<String>('dayName'),
            userWeight: r.read<String>('userWeight'),
            equipmentType: r.read<String>('equipmentType'),
            userComments: r.read<String>('userComments'),
            observedRpe: r.read<String>('observedRpe'),
            status: r.read<String>('status'),
          ),
        )
        .toList();
  }

  Future<void> deleteAll() async {
    await delete(exerciseLogs).go();
  }

  Future<void> deleteByProgramme(String programmeName) async {
    await customStatement(
      'DELETE FROM exercise_logs WHERE exerciseId IN '
      '(SELECT id FROM exercises WHERE programmeName = ?)',
      [programmeName],
    );
  }

  ExerciseLogRow _toLogRow(QueryRow r) => ExerciseLogRow(
        id: r.read<int>('id'),
        exerciseId: r.read<int>('exerciseId'),
        userWeight: r.read<String>('userWeight'),
        equipmentType: r.read<String>('equipmentType'),
        userComments: r.read<String>('userComments'),
        observedRpe: r.read<String>('observedRpe'),
        status: r.read<String>('status'),
      );
}
