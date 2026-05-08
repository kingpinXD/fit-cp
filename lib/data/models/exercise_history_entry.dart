class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.weekNumber,
    required this.userWeight,
    required this.equipmentType,
    required this.userComments,
    required this.observedRpe,
    required this.status,
  });

  final int weekNumber;
  final String userWeight;
  final String equipmentType;
  final String userComments;
  final String observedRpe;
  final String status;
}
