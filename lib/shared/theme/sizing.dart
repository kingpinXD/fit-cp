import 'package:flutter/material.dart';

/// Sizing scale — all spacing/padding/heights derive from this base unit.
/// Change [base] to uniformly scale the entire UI.
class FitSizing {
  const FitSizing({this.base = 4.0});

  final double base;

  double get xxs => base;
  double get xs => base * 2;
  double get sm => base * 3;
  double get md => base * 4;
  double get lg => base * 6;
  double get xl => base * 8;

  double get cardCorner => base * 3;
  double get chipCorner => base;
  double get buttonCorner => base * 3;
  double get inputHeight => base * 12;
  double get cardPadding => base * 3;
  double get cardGap => base * 2;
}

const FitSizing _defaultSizing = FitSizing();

class _FitSizingScope extends InheritedWidget {
  const _FitSizingScope({required this.sizing, required super.child});
  final FitSizing sizing;

  @override
  bool updateShouldNotify(_FitSizingScope oldWidget) =>
      sizing.base != oldWidget.sizing.base;
}

class FitSizingProvider extends StatelessWidget {
  const FitSizingProvider({
    super.key,
    this.sizing = _defaultSizing,
    required this.child,
  });

  final FitSizing sizing;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _FitSizingScope(sizing: sizing, child: child);
}

extension FitSizingContext on BuildContext {
  FitSizing get sizing {
    final scope = dependOnInheritedWidgetOfExactType<_FitSizingScope>();
    return scope?.sizing ?? _defaultSizing;
  }
}
