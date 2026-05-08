import 'package:drift/drift.dart';

@DataClassName('ExerciseRow')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get weekNumber => integer()();
  TextColumn get dayName => text()();
  TextColumn get exerciseName => text()();
  IntColumn get sets => integer()();
  TextColumn get reps => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get rpe => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get warmupSets => text().withDefault(const Constant('0'))();
  TextColumn get rest => text().withDefault(const Constant(''))();
  TextColumn get sub1 => text().withDefault(const Constant(''))();
  TextColumn get sub2 => text().withDefault(const Constant(''))();
  TextColumn get videoUrl => text().withDefault(const Constant(''))();
  TextColumn get sub1VideoUrl => text().withDefault(const Constant(''))();
  TextColumn get sub2VideoUrl => text().withDefault(const Constant(''))();
  TextColumn get programmeName => text().withDefault(const Constant(''))();
}
