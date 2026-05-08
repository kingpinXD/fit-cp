import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';

class ProgrammePickerDialog extends StatelessWidget {
  const ProgrammePickerDialog({
    super.key,
    required this.programmes,
    required this.onSelect,
  });

  final List<ProgrammeRow> programmes;
  final ValueChanged<ProgrammeRow> onSelect;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Programme'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in programmes)
              InkWell(
                onTap: () => onSelect(p),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
