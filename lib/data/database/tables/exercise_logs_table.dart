import 'package:drift/drift.dart';

@DataClassName('ExerciseLogRow')
class ExerciseLogs extends Table {
  @override
  String get tableName => 'exercise_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer()();
  TextColumn get userWeight => text()();
  TextColumn get equipmentType => text().withDefault(const Constant(''))();
  TextColumn get userComments => text()();
  TextColumn get observedRpe => text()();
  TextColumn get status => text()();
}
