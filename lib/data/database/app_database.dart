import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/exercise_dao.dart';
import 'daos/exercise_log_dao.dart';
import 'daos/programme_dao.dart';
import 'tables/exercise_logs_table.dart';
import 'tables/exercises_table.dart';
import 'tables/programmes_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Exercises, ExerciseLogs, Programmes],
  daos: [ExerciseDao, ExerciseLogDao, ProgrammeDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
