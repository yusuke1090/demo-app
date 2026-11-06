import 'package:farm_monitor/app_state.dart';
import 'package:farm_monitor/data/data_source.dart';
import 'package:farm_monitor/data/demo_data_source.dart';
import 'package:farm_monitor/main.dart';
import 'package:farm_monitor/models.dart';
import 'package:farm_monitor/screens/cows_screen.dart';
import 'package:farm_monitor/screens/soil_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, [DataSource? source]) => AppScope(
  state: AppState(source: source ?? DemoDataSource()),
  child: MaterialApp(home: home),
);

class _FailingSource extends DemoDataSource {
  @override
  Future<List<SoilSensor>> soilSensors() async =>
      throw const DataException('受信機に接続できません');
}

void main() {
  group('demo data', () {
    final source = DemoDataSource();

    test('each hour adds up to 60 minutes', () async {
      for (final cow in await source.cows()) {
        final detail = await source.cowDetail(cow.id);
        expect(detail.hours, hasLength(24));
        for (final h in detail.hours) {
          expect(h.minutes.values.reduce((a, b) => a + b), 60);
          expect(h.minutes.values.every((m) => m >= 0), isTrue);
        }
      }
    });

    test('statuses cover dry, good and offline', () async {
      final now = DateTime.now();
      final statuses = (await source.soilSensors()).map((s) => s.statusAt(now));
      expect(
        statuses,
        containsAll([SoilStatus.dry, SoilStatus.good, SoilStatus.offline]),
      );
    });

    test('the latest temperature is the current value', () async {
      final detail = await source.soilDetail('soil-3', hours: 24);
      expect(
        detail.history.last.temperature,
        closeTo(detail.sensor.temperature!, 0.001),
      );
    });

    test('a sensor without temperature has no temperature history', () async {
      final detail = await source.soilDetail('soil-4', hours: 24);
      expect(detail.history.every((p) => p.temperature == null), isTrue);
    });

    test('the latest soil point is the current value', () async {
      final detail = await source.soilDetail('soil-2', hours: 24);
      expect(detail.history, hasLength(25));
      expect(detail.history.last.moisture, detail.sensor.moisture);
    });
  });

  group('normalizeUrl', () {
    test('adds http and removes the trailing slash', () {
      expect(
        AppState.normalizeUrl(' 192.168.3.50:8080/ '),
        'http://192.168.3.50:8080',
      );
    });

    test('rejects unusable input', () {
      expect(AppState.normalizeUrl(''), isNull);
      expect(AppState.normalizeUrl('ftp://example.com'), isNull);
    });
  });

  testWidgets('home shows the summary and alerts', (tester) async {
    await tester.pumpWidget(FarmApp(state: AppState()));
    await tester.pumpAndSettle();
    expect(find.text('確認すること'), findsOneWidget);
    expect(find.textContaining('発情の候補'), findsOneWidget);
    expect(find.text('デモアプリ'), findsOneWidget);
    // 水分と牛が 2 / 4、温度が 2 / 3
    expect(find.text('2 / 4'), findsNWidgets(2));
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('tabs open moisture, temperature and cows separately', (
    tester,
  ) async {
    await tester.pumpWidget(FarmApp(state: AppState()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水分').last);
    await tester.pumpAndSettle();
    expect(find.text('土の水分'), findsOneWidget);
    expect(find.text('24.2%'), findsOneWidget);
    await tester.tap(find.text('温度').last);
    await tester.pumpAndSettle();
    expect(find.text('土の温度'), findsOneWidget);
    expect(find.text('20.8℃'), findsOneWidget);
    expect(find.textContaining('牧草地'), findsOneWidget);
    await tester.tap(find.text('牛').last);
    await tester.pumpAndSettle();
    expect(find.text('101 ハナ'), findsOneWidget);
  });

  testWidgets('soil detail changes the period', (tester) async {
    await tester.pumpWidget(_app(const SoilDetailScreen(id: 'soil-1')));
    await tester.pumpAndSettle();
    expect(find.text('畑A（ハウス東）'), findsOneWidget);
    await tester.tap(find.text('24時間'));
    await tester.pumpAndSettle();
    expect(find.text('畑A（ハウス東）'), findsOneWidget);
  });

  testWidgets('temperature detail shows the temperature', (tester) async {
    await tester.pumpWidget(
      _app(
        const SoilDetailScreen(id: 'soil-3', metric: SoilMetric.temperature),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('土の温度の記録'), findsOneWidget);
    expect(find.text('8.6℃'), findsOneWidget);
    expect(find.text('低温'), findsOneWidget);
  });

  testWidgets('cow detail says a flag is not a diagnosis', (tester) async {
    await tester.pumpWidget(_app(const CowDetailScreen(id: '103')));
    await tester.pumpAndSettle();
    expect(find.textContaining('診断ではなく'), findsOneWidget);
  });

  testWidgets('a failed load on home shows a message', (tester) async {
    await tester.pumpWidget(FarmApp(state: AppState(source: _FailingSource())));
    await tester.pumpAndSettle();
    expect(find.text('受信機に接続できません'), findsWidgets);
  });

  testWidgets('a failed load shows a message and a retry', (tester) async {
    await tester.pumpWidget(
      _app(const SoilScreen(metric: SoilMetric.moisture), _FailingSource()),
    );
    await tester.pumpAndSettle();
    expect(find.text('受信機に接続できません'), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);
  });
}
