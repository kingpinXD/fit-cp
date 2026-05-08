import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/models/exercise_history_entry.dart';
import '../../data/repositories/programme_repository.dart';

/// Override at the root with a real instance. Tests override with an
/// in-memory drift database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden');
});

/// Override at the root with a real instance. Tests override with mock prefs.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final programmeRepositoryProvider = Provider<ProgrammeRepository>((ref) {
  return ProgrammeRepository(
    db: ref.watch(appDatabaseProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

// ---- Streams scoped to the active programme name ----

final hasProgrammeProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(programmeRepositoryProvider);
  // Re-fire when the active name changes.
  ref.watch(programmeNameProvider);
  return repo.hasProgramme();
});

final programmeNameProvider =
    NotifierProvider<ProgrammeNameNotifier, String>(ProgrammeNameNotifier.new);

class ProgrammeNameNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(programmeRepositoryProvider).getProgrammeName();

  void update(String name) => state = name;
}

final weeksProvider = StreamProvider<List<int>>((ref) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getDistinctWeeks();
});

final completedWeeksProvider = StreamProvider<List<int>>((ref) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getCompletedWeeks();
});

final daysProvider = StreamProvider.family<List<String>, int>((ref, week) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getDistinctDays(week);
});

final completedDaysProvider =
    StreamProvider.family<List<String>, int>((ref, week) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getCompletedDays(week);
});

class WeekDay {
  const WeekDay(this.week, this.day);
  final int week;
  final String day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekDay && other.week == week && other.day == day;

  @override
  int get hashCode => Object.hash(week, day);
}

final exercisesProvider =
    StreamProvider.family<List<ExerciseRow>, WeekDay>((ref, wd) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getExercises(wd.week, wd.day);
});

final exerciseLogsProvider =
    StreamProvider.family<List<ExerciseLogRow>, WeekDay>((ref, wd) {
  final repo = ref.watch(programmeRepositoryProvider);
  ref.watch(programmeNameProvider);
  return repo.getLogsForDay(wd.week, wd.day);
});

final selectedExerciseLogProvider =
    StreamProvider.family<ExerciseLogRow?, int>((ref, exerciseId) {
  return ref.watch(programmeRepositoryProvider).getLog(exerciseId);
});

class ExerciseHistoryQuery {
  const ExerciseHistoryQuery(this.exerciseName, this.currentWeek);
  final String exerciseName;
  final int currentWeek;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseHistoryQuery &&
          other.exerciseName == exerciseName &&
          other.currentWeek == currentWeek;

  @override
  int get hashCode => Object.hash(exerciseName, currentWeek);
}

final exerciseHistoryProvider = StreamProvider.family<List<ExerciseHistoryEntry>,
    ExerciseHistoryQuery>((ref, q) {
  return ref
      .watch(programmeRepositoryProvider)
      .getHistory(q.exerciseName, q.currentWeek);
});

final availableProgrammesProvider = StreamProvider<List<ProgrammeRow>>((ref) {
  return ref.watch(programmeRepositoryProvider).getAvailableProgrammes();
});
