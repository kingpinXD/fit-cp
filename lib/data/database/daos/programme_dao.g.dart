// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'programme_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgrammeDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProgrammesTable get programmes => attachedDatabase.programmes;
  ProgrammeDaoManager get managers => ProgrammeDaoManager(this);
}

class ProgrammeDaoManager {
  final _$ProgrammeDaoMixin _db;
  ProgrammeDaoManager(this._db);
  $$ProgrammesTableTableManager get programmes =>
      $$ProgrammesTableTableManager(_db.attachedDatabase, _db.programmes);
}
