import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'programme_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return SettingsScreen(
        onBack: () => setState(() => _showSettings = false),
      );
    }
    return ProgrammeScreen(
      onNavigateToSettings: () => setState(() => _showSettings = true),
    );
  }
}
