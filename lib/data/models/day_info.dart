class DayInfo {
  const DayInfo({required this.weekNumber, required this.dayName});

  final int weekNumber;
  final String dayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayInfo &&
          other.weekNumber == weekNumber &&
          other.dayName == dayName;

  @override
  int get hashCode => Object.hash(weekNumber, dayName);

  @override
  String toString() => 'DayInfo($weekNumber, $dayName)';
}
