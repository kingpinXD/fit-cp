import 'package:flutter/material.dart';

import '../../../shared/theme/colors.dart';

class EquipmentChip extends StatelessWidget {
  const EquipmentChip({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = checked
        ? Colors.white.withValues(alpha: 0.15)
        : scheme.surfaceContainerHighest;
    final borderColor = checked ? Colors.white : scheme.outline;
    final textColor = checked ? Colors.white : textSecondary;

    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: checked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
