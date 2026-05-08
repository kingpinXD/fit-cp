import 'package:drift/drift.dart';

@DataClassName('ProgrammeRow')
class Programmes extends Table {
  TextColumn get name => text()();
  TextColumn get importedAt => text()();

  @override
  Set<Column> get primaryKey => {name};
}
