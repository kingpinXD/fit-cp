import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';

class WeekDropdown extends StatelessWidget {
  const WeekDropdown({
    super.key,
    required this.weeks,
    required this.completedWeeks,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<int> weeks;
  final List<int> completedWeeks;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedWeek =
        (weeks.isNotEmpty && selectedIndex < weeks.length) ? weeks[selectedIndex] : null;
    final isComplete =
        selectedWeek != null && completedWeeks.contains(selectedWeek);
    final label = selectedWeek != null
        ? (isComplete ? 'Week $selectedWeek ✓' : 'Week $selectedWeek')
        : 'Week';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'WEEK',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedIndex < weeks.length ? selectedIndex : null,
              hint: Text(label,
                  style: const TextStyle(color: Colors.white)),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: const TextStyle(color: Colors.white),
              items: [
                for (var i = 0; i < weeks.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Row(
                      children: [
                        Text('Week ${weeks[i]}'),
                        if (completedWeeks.contains(weeks[i]))
                          const Text(
                            ' ✓',
                            style: TextStyle(
                              color: successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onSelected(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class DayDropdown extends StatelessWidget {
  const DayDropdown({
    super.key,
    required this.days,
    required this.completedDays,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> days;
  final List<String> completedDays;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'DAY',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedIndex < days.length ? selectedIndex : null,
              hint: const Text('Day',
                  style: TextStyle(color: Colors.white)),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: const TextStyle(color: Colors.white),
              items: [
                for (var i = 0; i < days.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Row(
                      children: [
                        Text('Day ${i + 1}: ${days[i]}'),
                        if (completedDays.contains(days[i]))
                          const Text(
                            ' ✓',
                            style: TextStyle(
                              color: successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onSelected(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
