class ExportLogEntry {
  const ExportLogEntry({
    required this.exerciseName,
    required this.weekNumber,
    required this.dayName,
    required this.userWeight,
    required this.equipmentType,
    required this.userComments,
    required this.observedRpe,
    required this.status,
  });

  final String exerciseName;
  final int weekNumber;
  final String dayName;
  final String userWeight;
  final String equipmentType;
  final String userComments;
  final String observedRpe;
  final String status;
}
