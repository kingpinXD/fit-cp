/// Convert an RPE prescription string ("9-10", "8", "N/A") into a default
/// integer the slider should snap to (1..10). Mirrors the Kotlin helper.
int parseDefaultRpe(String rpe) {
  if (rpe.trim().isEmpty) return 5;
  final parts = rpe.split('-');
  final values = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p.trim());
    if (n != null) values.add(n);
  }
  if (values.isEmpty) return 5;
  final picked = values.reduce((a, b) => a > b ? a : b);
  if (picked < 1) return 1;
  if (picked > 10) return 10;
  return picked;
}
