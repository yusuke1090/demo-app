import 'dart:convert';
import 'dart:io';

import 'package:farm_monitor/data/data_source.dart';
import 'package:farm_monitor/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// アプリの読み取りと receiver/demo_server.py の応答の形が合っていることを確かめる。
void main() {
  late Process server;
  late ApiDataSource api;

  setUpAll(() async {
    server = await Process.start('python3', [
      'receiver/demo_server.py',
      '--host',
      '127.0.0.1',
      '--port',
      '0',
    ]);
    final line = await server.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final port = RegExp(r':(\d+)').firstMatch(line)!.group(1);
    api = ApiDataSource('http://127.0.0.1:$port');
  });

  tearDownAll(() => server.kill());

  test('reads every endpoint', () async {
    expect(await api.status(), 'デモ受信機');

    final sensors = await api.soilSensors();
    expect(sensors, hasLength(4));
    expect(sensors.last.statusAt(DateTime.now()), SoilStatus.offline);
    final soil = await api.soilDetail(sensors.first.id, hours: 24);
    expect(soil.history, hasLength(25));
    expect(soil.history.last.temperature, sensors.first.temperature);

    final cows = await api.cows();
    expect(cows, hasLength(4));
    final cow = await api.cowDetail(cows[1].id);
    expect(cow.cow.flag, '発情の候補');
    expect(cow.hours, hasLength(24));

    final alerts = await api.alerts();
    expect(
      alerts.map((a) => a.kind),
      containsAll(['cow', 'soil', 'temperature']),
    );
  });

  test('an unknown id becomes a readable error', () {
    expect(
      api.cowDetail('999'),
      throwsA(
        isA<DataException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('an unreachable receiver becomes a readable error', () {
    expect(
      ApiDataSource('http://127.0.0.1:1').status(),
      throwsA(isA<DataException>()),
    );
  });
}
