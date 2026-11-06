// 画面の見た目を PNG にする。ふだんのテストでは動かない。
//   SCREENSHOTS=1 flutter test --update-goldens test/screenshots_test.dart
import 'dart:io';

import 'package:farm_monitor/app_state.dart';
import 'package:farm_monitor/main.dart';
import 'package:farm_monitor/screens/cows_screen.dart';
import 'package:farm_monitor/screens/soil_screen.dart';
import 'package:farm_monitor/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';

  setUpAll(() async {
    if (!enabled) return;
    await _font(
      'Noto',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    await _font(
      'MaterialIcons',
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    Brightness brightness = Brightness.light,
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(brightness, fontFamily: 'Noto'),
          locale: const Locale('ja'),
          supportedLocales: const [Locale('ja')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$name.png'),
    );
  }

  final skip = !enabled;
  testWidgets('home', skip: skip, (t) => shot(t, 'home', const AppShell()));
  testWidgets(
    'soil',
    skip: skip,
    (t) => shot(t, 'soil', const AppShell(initialTab: 1)),
  );
  testWidgets(
    'soil-detail',
    skip: skip,
    (t) => shot(t, 'soil-detail', const SoilDetailScreen(id: 'soil-2')),
  );
  testWidgets(
    'temperature',
    skip: skip,
    (t) => shot(t, 'temperature', const AppShell(initialTab: 2)),
  );
  testWidgets(
    'temperature-detail',
    skip: skip,
    (t) => shot(
      t,
      'temperature-detail',
      const SoilDetailScreen(id: 'soil-3', metric: SoilMetric.temperature),
    ),
  );
  testWidgets(
    'cows',
    skip: skip,
    (t) => shot(t, 'cows', const AppShell(initialTab: 3)),
  );
  testWidgets(
    'cow-detail',
    skip: skip,
    (t) =>
        shot(t, 'cow-detail', const CowDetailScreen(id: '102'), height: 1000),
  );
  testWidgets(
    'cow-detail-dark',
    skip: skip,
    (t) => shot(
      t,
      'cow-detail-dark',
      const CowDetailScreen(id: '103'),
      brightness: Brightness.dark,
      height: 1000,
    ),
  );
  testWidgets(
    'settings',
    skip: skip,
    (t) => shot(t, 'settings', const AppShell(initialTab: 4)),
  );
}
