import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';
import '../../../shared/theme/colors.dart';

class ExerciseTable extends StatelessWidget {
  const ExerciseTable({super.key, required this.exercises});

  final List<ExerciseRow> exercises;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                SizedBox(
                  width: 32,
                  child: Text('#', style: _headerStyle),
                ),
                Expanded(child: Text('EXERCISE', style: _headerStyle)),
                SizedBox(width: 48, child: Text('SETS', style: _headerStyle)),
                SizedBox(width: 72, child: Text('REPS', style: _headerStyle)),
                SizedBox(width: 56, child: Text('RPE', style: _headerStyle)),
              ],
            ),
          ),
          Divider(color: scheme.outline, height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: exercises.length,
              separatorBuilder: (_, _) =>
                  Divider(color: scheme.outline.withValues(alpha: 0.5), height: 1),
              itemBuilder: (_, i) {
                final ex = exercises[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('${ex.orderIndex}',
                            style: const TextStyle(
                                color: textSecondary, fontSize: 14)),
                      ),
                      Expanded(
                        child: Text(ex.exerciseName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${ex.sets}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(ex.reps,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(ex.rpe,
                            style: const TextStyle(
                                color: textSecondary, fontSize: 14)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  color: textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.bold,
);
