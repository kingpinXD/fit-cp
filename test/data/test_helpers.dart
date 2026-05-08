import 'package:drift/drift.dart';
import 'package:fit_cp/data/database/app_database.dart';

/// View into a parsed [ExercisesCompanion] that exposes plain field values for
/// test assertions. Companion fields wrap values in `Value<T>` so reaching into
/// them inline gets verbose fast.
class ExerciseView {
  ExerciseView(ExercisesCompanion c)
      : weekNumber = c.weekNumber.value,
        dayName = c.dayName.value,
        exerciseName = c.exerciseName.value,
        sets = c.sets.value,
        reps = c.reps.value,
        orderIndex = c.orderIndex.value,
        rpe = _str(c.rpe),
        notes = _str(c.notes),
        warmupSets = _strOr(c.warmupSets, '0'),
        rest = _str(c.rest),
        sub1 = _str(c.sub1),
        sub2 = _str(c.sub2),
        videoUrl = _str(c.videoUrl),
        sub1VideoUrl = _str(c.sub1VideoUrl),
        sub2VideoUrl = _str(c.sub2VideoUrl);

  static String _str(Value<String> v) => v.present ? v.value : '';
  static String _strOr(Value<String> v, String d) => v.present ? v.value : d;

  final int weekNumber;
  final String dayName;
  final String exerciseName;
  final int sets;
  final String reps;
  final int orderIndex;
  final String rpe;
  final String notes;
  final String warmupSets;
  final String rest;
  final String sub1;
  final String sub2;
  final String videoUrl;
  final String sub1VideoUrl;
  final String sub2VideoUrl;
}

extension ExerciseCompanionListView on List<ExercisesCompanion> {
  List<ExerciseView> get views => map(ExerciseView.new).toList();
}
