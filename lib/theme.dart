import 'package:flutter/material.dart';

import 'models.dart';

const seedGreen = Color(0xFF2E7D32);

/// 状態の色。必ずアイコンと文字をいっしょに出す。
const statusGood = Color(0xFF0CA30C);
const statusWarning = Color(0xFFFAB219);
const statusCritical = Color(0xFFD03B3B);

ThemeData buildTheme(Brightness brightness, {String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedGreen,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: fontFamily,
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
    ),
  );
}

/// 行動の色。行動ごとに固定し、並び順で変えない。
Color behaviorColor(BuildContext context, Behavior b) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (b) {
    Behavior.rest => dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6),
    Behavior.eat => dark ? const Color(0xFFD95926) : const Color(0xFFEB6834),
    Behavior.walk => dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A),
    Behavior.ruminate =>
      dark ? const Color(0xFFC98500) : const Color(0xFFEDA100),
  };
}

IconData behaviorIcon(Behavior b) => switch (b) {
  Behavior.rest => Icons.bedtime_outlined,
  Behavior.eat => Icons.grass,
  Behavior.walk => Icons.directions_walk,
  Behavior.ruminate => Icons.autorenew,
};

/// 1本目の線の色
Color lineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF3987E5)
    : const Color(0xFF2A78D6);
