import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/app_database.dart';
import 'features/login/auth_gate.dart';
import 'features/programme/programme_providers.dart';
import 'shared/theme/sizing.dart';
import 'shared/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const FitApp(),
  ));
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit',
      theme: FitTheme.theme,
      home: const FitSizingProvider(child: AuthGate()),
    );
  }
}
