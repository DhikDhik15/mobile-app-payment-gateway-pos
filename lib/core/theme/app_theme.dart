import 'package:flutter/material.dart';

/// Application-wide theme configuration.
///
/// Centralises the visual design tokens (colors, typography, component
/// themes) so that all features share a consistent look and feel.
class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Color(0xFF1E3A5F);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );
}
