import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/database/app_database.dart';
import '../../../shared/theme/colors.dart';
import '../programme_notifier.dart';
import '../rpe.dart';
import 'equipment_chip.dart';

class ExerciseDetail extends StatefulWidget {
  const ExerciseDetail({
    super.key,
    required this.exercise,
    required this.existingLog,
    required this.prefill,
    required this.onPrefillConsumed,
    required this.onDone,
    required this.onSkip,
  });

  final ExerciseRow exercise;
  final ExerciseLogRow? existingLog;
  final PrefillEntry? prefill;
  final VoidCallback onPrefillConsumed;
  final void Function(String weight, String equipment, String comments,
      String rpe) onDone;
  final VoidCallback onSkip;

  @override
  State<ExerciseDetail> createState() => _ExerciseDetailState();
}

class _ExerciseDetailState extends State<ExerciseDetail> {
  late final TextEditingController _weight;
  late final TextEditingController _comments;
  late Map<String, bool> _equipment;
  late int _rpe;
  bool _notesExpanded = false;
  bool _altsExpanded = false;

  static const _equipmentLabels = [
    'Barbell',
    'Dumbbell',
    'Machine',
    'Each Side',
    'Cables',
    'Body Weight',
  ];

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController();
    _comments = TextEditingController();
    _equipment = {for (final l in _equipmentLabels) l: false};
    _seedFromLog();
  }

  @override
  void didUpdateWidget(covariant ExerciseDetail old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id ||
        old.existingLog?.id != widget.existingLog?.id) {
      _seedFromLog();
    }
    if (widget.prefill != null && old.prefill != widget.prefill) {
      _seedFromPrefill(widget.prefill!);
      widget.onPrefillConsumed();
    }
  }

  void _seedFromLog() {
    final log = widget.existingLog;
    _weight.text = log?.userWeight ?? '';
    _comments.text = log?.userComments ?? '';
    final tags =
        log?.equipmentType.split(',').map((s) => s.trim()).toSet() ?? {};
    _equipment = {for (final l in _equipmentLabels) l: tags.contains(l)};
    final logRpe = int.tryParse(log?.observedRpe ?? '');
    _rpe = logRpe ?? parseDefaultRpe(widget.exercise.rpe);
  }

  void _seedFromPrefill(PrefillEntry p) {
    _weight.text = p.weight;
    _comments.text = p.comments;
    final tags = p.equipment.split(',').map((s) => s.trim()).toSet();
    _equipment = {for (final l in _equipmentLabels) l: tags.contains(l)};
    _rpe = int.tryParse(p.observedRpe) ?? _rpe;
    setState(() {});
  }

  @override
  void dispose() {
    _weight.dispose();
    _comments.dispose();
    super.dispose();
  }

  String _equipmentCsv() => _equipment.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .join(',');

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = widget.exercise;
    final hasNotes = ex.notes.trim().isNotEmpty;
    final hasAlts =
        ex.sub1.trim().isNotEmpty || ex.sub2.trim().isNotEmpty;

    final rpeStr = ex.rpe.trim().isNotEmpty ? ' | RPE: ${ex.rpe}' : '';
    final restStr = ex.rest.trim().isNotEmpty ? ' | Rest: ${ex.rest}' : '';

    return Card(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openUrl(ex.videoUrl),
              child: Text(
                ex.videoUrl.isNotEmpty
                    ? '${ex.exerciseName} ▶'
                    : ex.exerciseName,
                style: TextStyle(
                  color: ex.videoUrl.isNotEmpty ? skipBlue : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (ex.warmupSets != '0')
              Text(
                'Warm-up: ${ex.warmupSets} sets × ${ex.reps.replaceAll(RegExp(r'\s*\(.*\)'), '')}',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            Text(
              'Working: ${ex.sets} sets × ${ex.reps}$rpeStr$restStr',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            if (hasNotes || hasAlts) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  if (hasNotes)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _notesExpanded = !_notesExpanded),
                      child: Text(
                        _notesExpanded ? 'Notes ▼' : 'Notes ▶',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 11),
                      ),
                    ),
                  if (hasNotes && hasAlts) const SizedBox(width: 8),
                  if (hasAlts)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _altsExpanded = !_altsExpanded),
                      child: Text(
                        _altsExpanded ? 'Alts ▼' : 'Alts ▶',
                        style: const TextStyle(
                            color: textSecondary, fontSize: 11),
                      ),
                    ),
                ],
              ),
              if (_notesExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Text(
                    ex.notes,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (_altsExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ex.sub1.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () => _openUrl(ex.sub1VideoUrl),
                          child: Text(
                            ex.sub1VideoUrl.isNotEmpty
                                ? '• ${ex.sub1} ▶'
                                : '• ${ex.sub1}',
                            style: TextStyle(
                              color: ex.sub1VideoUrl.isNotEmpty
                                  ? skipBlue
                                  : textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (ex.sub2.trim().isNotEmpty)
                        GestureDetector(
                          onTap: () => _openUrl(ex.sub2VideoUrl),
                          child: Text(
                            ex.sub2VideoUrl.isNotEmpty
                                ? '• ${ex.sub2} ▶'
                                : '• ${ex.sub2}',
                            style: TextStyle(
                              color: ex.sub2VideoUrl.isNotEmpty
                                  ? skipBlue
                                  : textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _weight,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Wt',
                      labelStyle: TextStyle(fontSize: 9),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      _equipmentRow(
                          ['Barbell', 'Dumbbell', 'Machine']),
                      const SizedBox(height: 2),
                      _equipmentRow(
                          ['Each Side', 'Cables', 'Body Weight']),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RPE',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                Text(
                  '$_rpe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _rpe.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: Colors.white,
              inactiveColor: scheme.outline,
              onChanged: (v) => setState(() => _rpe = v.toInt()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= 10; i++)
                  Text(
                    '$i',
                    style: TextStyle(
                      color: i == _rpe ? Colors.white : textSecondary,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _comments,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Comments (opt)',
                labelStyle: TextStyle(fontSize: 10),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onDone(
                      _weight.text,
                      _equipmentCsv(),
                      _comments.text,
                      '$_rpe',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: skipBlue,
                      side: const BorderSide(color: skipBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SKIP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _equipmentRow(List<String> labels) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: EquipmentChip(
              label: labels[i],
              checked: _equipment[labels[i]]!,
              onChanged: (v) =>
                  setState(() => _equipment[labels[i]] = v),
            ),
          ),
        ],
      ],
    );
  }
}
