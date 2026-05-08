import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../shared/theme/colors.dart';
import 'import_helper.dart';
import 'programme_notifier.dart';
import 'programme_providers.dart';
import 'widgets/exercise_detail.dart';
import 'widgets/exercise_list_item.dart';
import 'widgets/exercise_table.dart';
import 'widgets/history_overlay.dart';
import 'widgets/programme_picker_dialog.dart';
import 'widgets/week_day_dropdowns.dart';

class ProgrammeScreen extends ConsumerStatefulWidget {
  const ProgrammeScreen({super.key, required this.onNavigateToSettings});

  final VoidCallback onNavigateToSettings;

  @override
  ConsumerState<ProgrammeScreen> createState() => _ProgrammeScreenState();
}

class _ProgrammeScreenState extends ConsumerState<ProgrammeScreen> {
  int _weekIndex = 0;
  int _dayIndex = 0;
  bool _initialSelectionDone = false;

  @override
  Widget build(BuildContext context) {
    final hasProgrammeAsync = ref.watch(hasProgrammeProvider);
    return hasProgrammeAsync.when(
      loading: () => const Scaffold(
        backgroundColor: backgroundBlack,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (_, _) => const _ImportVariant(),
      data: (has) => has ? _buildMain() : const _ImportVariant(),
    );
  }

  Widget _buildMain() {
    final programmeName = ref.watch(programmeNameProvider);
    final weeksAsync = ref.watch(weeksProvider);
    final completedWeeksAsync = ref.watch(completedWeeksProvider);
    final state = ref.watch(programmeNotifierProvider);
    final notifier = ref.read(programmeNotifierProvider.notifier);

    final weeks = weeksAsync.value ?? const <int>[];
    final completedWeeks = completedWeeksAsync.value ?? const <int>[];

    // Auto-select initial week once weeks load.
    if (weeks.isNotEmpty && state.selectedWeek == null) {
      final target = state.initialDay?.weekNumber ?? weeks.last;
      final idx = weeks.indexOf(target).clamp(0, weeks.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifier.selectWeek(weeks[idx]);
        setState(() => _weekIndex = idx);
      });
    }

    final selectedWeek = state.selectedWeek ?? weeks.firstOrNull;
    final daysAsync = selectedWeek == null
        ? const AsyncValue<List<String>>.data(<String>[])
        : ref.watch(daysProvider(selectedWeek));
    final completedDaysAsync = selectedWeek == null
        ? const AsyncValue<List<String>>.data(<String>[])
        : ref.watch(completedDaysProvider(selectedWeek));
    final days = daysAsync.value ?? const <String>[];
    final completedDays = completedDaysAsync.value ?? const <String>[];

    if (days.isNotEmpty &&
        selectedWeek != null &&
        state.selectedDay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_initialSelectionDone &&
            state.initialDay != null &&
            state.initialDay!.weekNumber == selectedWeek) {
          final idx = days.indexOf(state.initialDay!.dayName);
          if (idx >= 0) {
            setState(() {
              _dayIndex = idx;
              _initialSelectionDone = true;
            });
            notifier.selectDay(days[idx]);
          }
        } else if (!_initialSelectionDone && state.initialDay == null) {
          setState(() {
            _dayIndex = days.length - 1;
            _initialSelectionDone = true;
          });
          notifier.selectDay(days.last);
        } else {
          setState(() => _dayIndex = 0);
          notifier.selectDay(days.first);
        }
      });
    }

    final selectedDay = state.selectedDay;
    final exercisesAsync = (selectedWeek != null && selectedDay != null)
        ? ref.watch(exercisesProvider(WeekDay(selectedWeek, selectedDay)))
        : const AsyncValue<List<ExerciseRow>>.data(<ExerciseRow>[]);
    final logsAsync = (selectedWeek != null && selectedDay != null)
        ? ref.watch(exerciseLogsProvider(WeekDay(selectedWeek, selectedDay)))
        : const AsyncValue<List<ExerciseLogRow>>.data(<ExerciseLogRow>[]);
    final exercises = exercisesAsync.value ?? const <ExerciseRow>[];
    final logs = logsAsync.value ?? const <ExerciseLogRow>[];
    final logsById = {for (final l in logs) l.exerciseId: l};

    final selectedExerciseLogAsync = state.selectedExercise == null
        ? const AsyncValue<ExerciseLogRow?>.data(null)
        : ref.watch(selectedExerciseLogProvider(state.selectedExercise!.id));

    final historyAsync = state.selectedExercise == null
        ? null
        : ref.watch(exerciseHistoryProvider(ExerciseHistoryQuery(
            state.selectedExercise!.exerciseName,
            state.selectedExercise!.weekNumber,
          )));

    return Scaffold(
      backgroundColor: backgroundBlack,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(programmeName),
                _dropdownRow(weeks, completedWeeks, days, completedDays),
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    crossAxisCount: 2,
                    childAspectRatio: 4.5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [
                      for (final ex in exercises)
                        ExerciseListItem(
                          exercise: ex,
                          isSelected:
                              ex.id == state.selectedExercise?.id,
                          log: logsById[ex.id],
                          onTap: () {
                            notifier.selectExercise(ex);
                            notifier.setShowTable(false);
                            notifier.setShowHistory(false);
                          },
                          onLongPress: () {
                            notifier.selectExercise(ex);
                            notifier.setShowTable(false);
                            notifier.setShowHistory(true);
                          },
                        ),
                      _ShowTableTile(
                        isSelected: state.showTable,
                        onTap: () {
                          notifier.selectExercise(null);
                          notifier.setShowTable(true);
                        },
                      ),
                    ],
                  ),
                ),
                if (state.showTable)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ExerciseTable(exercises: exercises),
                    ),
                  )
                else if (state.selectedExercise != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: ExerciseDetail(
                      exercise: state.selectedExercise!,
                      existingLog: selectedExerciseLogAsync.value,
                      prefill: state.prefillEntry,
                      onPrefillConsumed: notifier.clearPrefill,
                      onDone: (weight, eq, comments, rpe) async {
                        await notifier.markDone(
                            state.selectedExercise!,
                            weight,
                            eq,
                            comments,
                            rpe);
                        notifier.setShowHistory(false);
                        _advanceToNext(notifier, exercises);
                      },
                      onSkip: () async {
                        await notifier.markSkipped(state.selectedExercise!);
                        notifier.setShowHistory(false);
                        _advanceToNext(notifier, exercises);
                      },
                    ),
                  ),
              ],
            ),
            if (state.showHistory &&
                state.selectedExercise != null &&
                historyAsync != null)
              HistoryOverlay(
                exerciseName: state.selectedExercise!.exerciseName,
                history: historyAsync.value ?? const [],
                onDismiss: () => notifier.setShowHistory(false),
                onCopy: (entry) {
                  notifier.prefillFromHistory(PrefillEntry(
                    weight: entry.userWeight,
                    equipment: entry.equipmentType,
                    observedRpe: entry.observedRpe,
                    comments: entry.userComments,
                  ));
                  notifier.setShowHistory(false);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _advanceToNext(ProgrammeNotifier notifier, List<ExerciseRow> exercises) {
    final current = ref.read(programmeNotifierProvider).selectedExercise;
    if (current == null) return;
    final idx = exercises.indexWhere((e) => e.id == current.id);
    if (idx < 0) return;
    final next = idx + 1 < exercises.length ? exercises[idx + 1] : current;
    notifier.selectExercise(next);
  }

  Widget _topBar(String programmeName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            programmeName.isEmpty ? 'Fit' : programmeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: widget.onNavigateToSettings,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(
    List<int> weeks,
    List<int> completedWeeks,
    List<String> days,
    List<String> completedDays,
  ) {
    final notifier = ref.read(programmeNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: scheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: WeekDropdown(
                  weeks: weeks,
                  completedWeeks: completedWeeks,
                  selectedIndex: _weekIndex,
                  onSelected: (i) {
                    setState(() {
                      _weekIndex = i;
                      _initialSelectionDone = false;
                    });
                    notifier.selectWeek(weeks[i]);
                    notifier.selectDay(null);
                    notifier.selectExercise(null);
                    notifier.setShowTable(false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DayDropdown(
                  days: days,
                  completedDays: completedDays,
                  selectedIndex: _dayIndex,
                  onSelected: (i) {
                    setState(() => _dayIndex = i);
                    notifier.selectDay(days[i]);
                    notifier.selectExercise(null);
                    notifier.setShowTable(false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowTableTile extends StatelessWidget {
  const _ShowTableTile({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Text(
          'Show Table',
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ImportVariant extends ConsumerStatefulWidget {
  const _ImportVariant();

  @override
  ConsumerState<_ImportVariant> createState() => _ImportVariantState();
}

class _ImportVariantState extends ConsumerState<_ImportVariant> {
  bool _importing = false;

  Future<void> _doImport() async {
    setState(() => _importing = true);
    try {
      final sel = await pickProgrammeFile();
      if (sel == null) return;
      final notifier = ref.read(programmeNotifierProvider.notifier);
      final result = await applyImport(notifier, sel);
      if (mounted && result != null) {
        showImportSnack(context, result, sel.programmeName);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showPicker() async {
    final available =
        await ref.read(availableProgrammesProvider.future);
    if (!mounted || available.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ProgrammePickerDialog(
        programmes: available,
        onSelect: (p) => Navigator.of(context).pop(p.name),
      ),
    );
    if (picked != null && mounted) {
      await ref
          .read(programmeNotifierProvider.notifier)
          .switchProgramme(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: backgroundBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Fit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your programme',
                  style: TextStyle(color: textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 48),
                if (_importing)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _showPicker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'USE EXISTING',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _doImport,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'IMPORT PROGRAMME',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
