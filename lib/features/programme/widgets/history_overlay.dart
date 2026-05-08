import 'package:flutter/material.dart';

import '../../../data/models/exercise_history_entry.dart';
import '../../../shared/theme/colors.dart';

class HistoryOverlay extends StatelessWidget {
  const HistoryOverlay({
    super.key,
    required this.exerciseName,
    required this.history,
    required this.onDismiss,
    required this.onCopy,
  });

  final String exerciseName;
  final List<ExerciseHistoryEntry> history;
  final VoidCallback onDismiss;
  final ValueChanged<ExerciseHistoryEntry> onCopy;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDismiss();
      },
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: onDismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('×',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 20)),
                        ),
                      ),
                    ),
                    Text(
                      exerciseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PREVIOUS WEEKS',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Text(
                        'No data available',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final entry in history.reversed)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: _HistoryCard(
                                    entry: entry,
                                    onLongPress: () => onCopy(entry),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onLongPress});

  final ExerciseHistoryEntry entry;
  final VoidCallback onLongPress;

  static const _shortEquipment = {
    'Barbell': 'BB',
    'Dumbbell': 'DB',
    'Machine': 'MN',
    'Each Side': 'ES',
    'Cables': 'CB',
    'Body Weight': 'BW',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final equipmentTags = entry.equipmentType
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'W${entry.weekNumber}',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              if (entry.userWeight.trim().isNotEmpty)
                Text(
                  entry.userWeight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  entry.status == 'SKIPPED' ? 'Skipped' : '—',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(width: 12),
              if (entry.observedRpe.trim().isNotEmpty)
                _Chip(label: entry.observedRpe, color: rpePurple),
              for (final tag in equipmentTags) ...[
                const SizedBox(width: 4),
                _Chip(
                  label: _shortEquipment[tag] ?? tag,
                  color: equipmentGreen,
                ),
              ],
              if (entry.userComments.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.userComments,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
