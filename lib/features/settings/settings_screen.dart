import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' as pkg;
import 'package:share_plus/share_plus.dart';

import '../../shared/theme/colors.dart';
import '../programme/import_helper.dart';
import '../programme/programme_notifier.dart';
import '../programme/programme_providers.dart';
import '../programme/widgets/programme_picker_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await pkg.PackageInfo.fromPlatform();
      if (mounted) setState(() => _versionLabel = 'v${info.version}');
    } catch (_) {
      // PackageInfo can fail in tests; fall back silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: backgroundBlack,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SettingsCard(
              text: 'Switch Programme',
              onTap: _showSwitcher,
            ),
            const SizedBox(height: 8),
            _SettingsCard(
              text: 'Import Programme',
              onTap: _doImport,
            ),
            const SizedBox(height: 8),
            _SettingsCard(
              text: 'Export Programme',
              onTap: _showExport,
            ),
            const SizedBox(height: 8),
            _SettingsCard(
              text: 'Start New Cycle',
              onTap: _showCycle,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Delete Programme',
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_versionLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _versionLabel!,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doImport() async {
    final sel = await pickProgrammeFile();
    if (sel == null) return;
    final notifier = ref.read(programmeNotifierProvider.notifier);
    final result = await applyImport(notifier, sel);
    if (mounted && result != null) {
      showImportSnack(context, result, sel.programmeName);
      widget.onBack();
    }
  }

  Future<void> _showSwitcher() async {
    final available = await ref.read(availableProgrammesProvider.future);
    if (!mounted || available.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ProgrammePickerDialog(
        programmes: available,
        onSelect: (p) => Navigator.of(context).pop(p.name),
      ),
    );
    if (picked != null && mounted) {
      await ref
          .read(programmeNotifierProvider.notifier)
          .switchProgramme(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to $picked')),
      );
      widget.onBack();
    }
  }

  Future<void> _showDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Programme'),
        content: const Text(
          'Are you sure? This will delete the programme and all logged data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(programmeNotifierProvider.notifier).deleteProgramme();
    if (mounted) widget.onBack();
  }

  Future<void> _showExport() async {
    final id = await _identifierDialog(
      title: 'Export Programme',
      cta: 'Export',
    );
    if (id == null || !mounted) return;
    final notifier = ref.read(programmeNotifierProvider.notifier);
    final outcome = await notifier.exportProgramme(id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(
        outcome.firebaseOk ? 'Exported to cloud' : 'Export failed (cloud)',
      ),
    ));
    if (outcome.json != null) {
      await Share.share(
        outcome.json!,
        subject: 'Fit Programme Export',
      );
    }
  }

  Future<void> _showCycle() async {
    final id = await _identifierDialog(
      title: 'Start New Cycle',
      cta: 'Start',
      hint:
          'This will export your current data and reset the programme for a fresh cycle.',
    );
    if (id == null || !mounted) return;
    final notifier = ref.read(programmeNotifierProvider.notifier);
    final outcome = await notifier.exportProgramme(id);
    if (!mounted) return;
    if (outcome.firebaseOk) {
      await notifier.deleteProgramme();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cycle exported and reset')),
      );
      widget.onBack();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Export failed - cycle not reset')),
      );
    }
  }

  Future<String?> _identifierDialog({
    required String title,
    required String cta,
    String? hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Text(hint, style: const TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'e.g. Round 1, Jan 2026',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final id = controller.text
                  .trim()
                  .toLowerCase()
                  .replaceAll(' ', '_');
              Navigator.of(context).pop(id);
            },
            child: Text(cta),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
