import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared/theme/sizing.dart';
import 'shared/theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: FitApp()));
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit',
      theme: FitTheme.theme,
      home: const FitSizingProvider(
        child: Scaffold(body: Center(child: Text('Fit'))),
      ),
    );
  }
}
