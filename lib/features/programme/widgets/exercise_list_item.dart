import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';
import '../../../shared/theme/colors.dart';

class ExerciseListItem extends StatelessWidget {
  const ExerciseListItem({
    super.key,
    required this.exercise,
    required this.isSelected,
    required this.log,
    required this.onTap,
    required this.onLongPress,
  });

  final ExerciseRow exercise;
  final bool isSelected;
  final ExerciseLogRow? log;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isSelected ? scheme.surfaceContainerHighest : scheme.surface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: isSelected
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.white, width: 3),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${exercise.orderIndex}.',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (log?.status == 'DONE')
                const Text(
                  '✓',
                  style: TextStyle(
                    color: successGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (log?.status == 'SKIPPED')
                const Text(
                  '↻',
                  style: TextStyle(
                    color: skipBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
