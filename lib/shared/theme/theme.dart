import 'package:flutter/material.dart';

import 'colors.dart';

class FitTheme {
  static ThemeData get theme {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: surfaceVariant,
      secondary: textSecondary,
      onSecondary: Colors.black,
      surface: surfaceDark,
      onSurface: Colors.white,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: textSecondary,
      outline: outlineGray,
      error: errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundBlack,
      canvasColor: backgroundBlack,
    );
  }
}
