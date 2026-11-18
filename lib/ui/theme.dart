import 'package:flutter/material.dart';

import '../models.dart';

const _seed = Color(0xFFB8913A); // warmes Gold

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  if (dark) {
    scheme = scheme.copyWith(
      surface: const Color(0xFF121212),
      surfaceContainerLowest: const Color(0xFF0B0B0B),
      surfaceContainerLow: const Color(0xFF171717),
      surfaceContainer: const Color(0xFF1C1C1C),
      surfaceContainerHigh: const Color(0xFF232323),
      surfaceContainerHighest: const Color(0xFF2B2B2B),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

IconData typeIcon(EntryType t) => switch (t) {
      EntryType.goal => Icons.flag_outlined,
      EntryType.idea => Icons.lightbulb_outline,
      EntryType.info => Icons.bookmark_border,
    };

Color typeColor(BuildContext context, EntryType t) {
  final s = Theme.of(context).colorScheme;
  return switch (t) {
    EntryType.goal => s.primary,
    EntryType.idea => s.tertiary,
    EntryType.info => s.secondary,
  };
}
