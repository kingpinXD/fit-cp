import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/models/day_info.dart';
import '../../data/models/import_result.dart';
import '../../data/sync/firebase_sync_manager.dart';
import 'programme_providers.dart';

class ExportOutcome {
  const ExportOutcome({required this.json, required this.firebaseOk});
  final String? json;
  final bool firebaseOk;
}

class ProgrammeUiState {
  const ProgrammeUiState({
    this.selectedWeek,
    this.selectedDay,
    this.selectedExercise,
    this.showTable = false,
    this.showHistory = false,
    this.initialDay,
    this.prefillEntry,
  });

  final int? selectedWeek;
  final String? selectedDay;
  final ExerciseRow? selectedExercise;
  final bool showTable;
  final bool showHistory;
  final DayInfo? initialDay;
  final PrefillEntry? prefillEntry;

  ProgrammeUiState copyWith({
    int? selectedWeek,
    String? selectedDay,
    ExerciseRow? selectedExercise,
    bool? showTable,
    bool? showHistory,
    DayInfo? initialDay,
    PrefillEntry? prefillEntry,
    bool clearSelectedWeek = false,
    bool clearSelectedDay = false,
    bool clearSelectedExercise = false,
    bool clearInitialDay = false,
    bool clearPrefillEntry = false,
  }) {
    return ProgrammeUiState(
      selectedWeek:
          clearSelectedWeek ? null : (selectedWeek ?? this.selectedWeek),
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      selectedExercise: clearSelectedExercise
          ? null
          : (selectedExercise ?? this.selectedExercise),
      showTable: showTable ?? this.showTable,
      showHistory: showHistory ?? this.showHistory,
      initialDay: clearInitialDay ? null : (initialDay ?? this.initialDay),
      prefillEntry:
          clearPrefillEntry ? null : (prefillEntry ?? this.prefillEntry),
    );
  }
}

/// Bundle the user-supplied detail-panel inputs so a long-pressed history
/// card can seed the form on the next exercise.
class PrefillEntry {
  const PrefillEntry({
    required this.weight,
    required this.equipment,
    required this.observedRpe,
    required this.comments,
  });

  final String weight;
  final String equipment;
  final String observedRpe;
  final String comments;
}

final programmeNotifierProvider =
    NotifierProvider<ProgrammeNotifier, ProgrammeUiState>(
  ProgrammeNotifier.new,
);

class ProgrammeNotifier extends Notifier<ProgrammeUiState> {
  @override
  ProgrammeUiState build() {
    // Kick off preload + initial day lookup. Both are best-effort.
    Future.microtask(_bootstrap);
    return const ProgrammeUiState();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(programmeRepositoryProvider);
    try {
      await repo.preloadProgrammes();
    } catch (_) {
      // preload is best-effort; tests inject fixtures differently
    }
    try {
      final initial = await repo.getFirstIncompleteDay();
      state = state.copyWith(initialDay: initial);
    } catch (_) {
      // no programme yet
    }
  }

  void selectWeek(int? week) =>
      state = state.copyWith(
        selectedWeek: week,
        clearSelectedWeek: week == null,
      );

  void selectDay(String? day) =>
      state = state.copyWith(
        selectedDay: day,
        clearSelectedDay: day == null,
      );

  void selectExercise(ExerciseRow? ex) =>
      state = state.copyWith(
        selectedExercise: ex,
        clearSelectedExercise: ex == null,
      );

  void setShowTable(bool show) => state = state.copyWith(showTable: show);
  void setShowHistory(bool show) => state = state.copyWith(showHistory: show);

  void prefillFromHistory(PrefillEntry entry) =>
      state = state.copyWith(prefillEntry: entry);

  void clearPrefill() =>
      state = state.copyWith(clearPrefillEntry: true);

  Future<ImportResult?> importProgramme(String json, String name) async {
    try {
      final repo = ref.read(programmeRepositoryProvider);
      final result = await repo.importProgrammeFromJson(json, name);
      ref.read(programmeNameProvider.notifier).update(repo.getProgrammeName());
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<ImportResult?> importProgrammeFromXlsx(
    Uint8List bytes,
    String name,
  ) async {
    try {
      final repo = ref.read(programmeRepositoryProvider);
      final result = await repo.importProgrammeFromXlsx(bytes, name);
      ref.read(programmeNameProvider.notifier).update(repo.getProgrammeName());
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> switchProgramme(String name) async {
    final repo = ref.read(programmeRepositoryProvider);
    await repo.setProgrammeName(name);
    ref.read(programmeNameProvider.notifier).update(name);
  }

  Future<void> deleteProgramme() async {
    try {
      await ref.read(programmeRepositoryProvider).deleteProgramme();
      ref.read(programmeNameProvider.notifier).update('');
      state = const ProgrammeUiState();
    } catch (_) {
      // swallow per Kotlin behaviour
    }
  }

  Future<ExportOutcome> exportProgramme(String identifier) async {
    try {
      final repo = ref.read(programmeRepositoryProvider);
      final name = ref.read(programmeNameProvider);
      final json = await repo.buildExportJson(name, identifier);
      final sync = ref.read(firebaseSyncManagerProvider);
      final ok = await sync.exportProgramme(name, identifier, json);
      return ExportOutcome(json: json, firebaseOk: ok);
    } catch (_) {
      return const ExportOutcome(json: null, firebaseOk: false);
    }
  }

  Future<void> markDone(
    ExerciseRow exercise,
    String weight,
    String equipment,
    String comments,
    String observedRpe,
  ) async {
    final repo = ref.read(programmeRepositoryProvider);
    final rpe = observedRpe.trim().isEmpty ? exercise.rpe : observedRpe;
    final existing = await repo.getLogSync(exercise.id);
    await repo.saveLog(ExerciseLogsCompanion(
      id: existing != null ? Value(existing.id) : const Value.absent(),
      exerciseId: Value(exercise.id),
      userWeight: Value(weight),
      equipmentType: Value(equipment),
      userComments: Value(comments),
      observedRpe: Value(rpe),
      status: const Value('DONE'),
    ));
  }

  Future<void> markSkipped(ExerciseRow exercise) async {
    final repo = ref.read(programmeRepositoryProvider);
    final existing = await repo.getLogSync(exercise.id);
    await repo.saveLog(ExerciseLogsCompanion(
      id: existing != null ? Value(existing.id) : const Value.absent(),
      exerciseId: Value(exercise.id),
      userWeight: const Value(''),
      equipmentType: const Value(''),
      userComments: const Value(''),
      observedRpe: const Value(''),
      status: const Value('SKIPPED'),
    ));
  }
}
