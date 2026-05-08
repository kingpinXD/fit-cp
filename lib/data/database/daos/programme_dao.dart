import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/programmes_table.dart';

part 'programme_dao.g.dart';

@DriftAccessor(tables: [Programmes])
class ProgrammeDao extends DatabaseAccessor<AppDatabase>
    with _$ProgrammeDaoMixin {
  ProgrammeDao(super.db);

  Future<void> upsert(ProgrammesCompanion programme) async {
    await into(programmes).insertOnConflictUpdate(programme);
  }

  Stream<List<ProgrammeRow>> watchAll() {
    return (select(programmes)
          ..orderBy([
            (p) => OrderingTerm(
                  expression: p.importedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Future<List<ProgrammeRow>> getAll() {
    return (select(programmes)
          ..orderBy([
            (p) => OrderingTerm(
                  expression: p.importedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<bool> exists(String name) async {
    final query = selectOnly(programmes)
      ..addColumns([programmes.name.count()])
      ..where(programmes.name.equals(name));
    final row = await query.getSingle();
    return (row.read(programmes.name.count()) ?? 0) > 0;
  }

  Future<void> deleteByName(String name) async {
    await (delete(programmes)..where((p) => p.name.equals(name))).go();
  }
}
