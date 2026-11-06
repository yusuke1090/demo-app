import 'dart:math';

import '../models.dart';
import 'data_source.dart';

/// 実機がなくても画面を確認するための、作り物のデータ。
class DemoDataSource implements DataSource {
  DemoDataSource({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _soil = [
    _SoilSpec('soil-1', '畑A', 'ハウス東', 42.5, 21.3, 86, 2, 30, 60, 0),
    _SoilSpec('soil-2', '畑B', 'ハウス西', 24.2, 20.8, 71, 4, 30, 60, 0),
    _SoilSpec('soil-3', '畑C', '露地 南側', 55.8, 8.6, 64, 7, 30, 60, 0),
    _SoilSpec('soil-4', '牧草地', '北の区画', 38.0, null, 12, 0, 25, 55, 3),
  ];

  static const _cows = [
    _CowSpec('101', 'ハナ', 1, 92, _Pattern.normal),
    _CowSpec('102', 'モモ', 2, 78, _Pattern.estrus),
    _CowSpec('103', 'サクラ', 3, 64, _Pattern.lowRumination),
    _CowSpec('104', 'ユキ', 4, 17, _Pattern.normal),
  ];

  @override
  Future<String> status() async => 'デモデータ';

  @override
  Future<List<SoilSensor>> soilSensors() async =>
      _soil.map((s) => s.sensor(_clock())).toList();

  @override
  Future<SoilDetail> soilDetail(String id, {int hours = 168}) async {
    final spec = _soil.firstWhere(
      (s) => s.id == id,
      orElse: () => throw DataException('センサー $id が見つかりません'),
    );
    final sensor = spec.sensor(_clock());
    final history = [
      for (var t = hours; t >= 0; t--)
        SoilPoint(
          sensor.updatedAt.subtract(Duration(hours: t)),
          // 水やりの間に少しずつ乾き、72時間ごとに水分が戻る形
          t == 0
              ? spec.moisture
              : spec.moisture +
                    (t % 72) * 0.2 +
                    0.6 * sin(t * 0.7 + spec.moisture),
          _temperature(spec, sensor.updatedAt, t),
        ),
    ];
    return SoilDetail(sensor, history);
  }

  /// 今の値を基準に、昼に上がり夜に下がる形にする。
  static double? _temperature(
    _SoilSpec spec,
    DateTime updatedAt,
    int hoursAgo,
  ) {
    final current = spec.temperature;
    if (current == null) return null;
    double wave(DateTime t) => 2.5 * sin((t.hour - 8) / 24 * 2 * pi);
    final time = updatedAt.subtract(Duration(hours: hoursAgo));
    return current + wave(time) - wave(updatedAt);
  }

  @override
  Future<List<Cow>> cows() async =>
      _cows.map((c) => _cowDetail(c).cow).toList();

  @override
  Future<CowDetail> cowDetail(String id) async => _cowDetail(
    _cows.firstWhere(
      (c) => c.id == id,
      orElse: () => throw DataException('牛 $id が見つかりません'),
    ),
  );

  CowDetail _cowDetail(_CowSpec spec) {
    final now = _clock();
    final thisHour = DateTime(now.year, now.month, now.day, now.hour);
    final hours = [
      for (var i = 23; i >= 0; i--)
        _cowHour(spec, thisHour.subtract(Duration(hours: i)), i),
    ];
    final totals = {
      for (final b in Behavior.values)
        b: hours.fold<int>(0, (sum, h) => sum + h.minutes[b]!),
    };
    final latest = hours.last.minutes.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    var usualRuminate = 0.0;
    for (var h = 0; h < 24; h++) {
      usualRuminate += _usual(h)[Behavior.ruminate]!;
    }
    return CowDetail(
      Cow(
        id: spec.id,
        name: spec.name,
        current: latest.key,
        battery: spec.battery,
        updatedAt: now.subtract(Duration(minutes: spec.seed)),
        last24h: totals,
        usualRuminate: usualRuminate.round(),
        flag: spec.pattern.flag,
      ),
      hours,
    );
  }

  CowHour _cowHour(_CowSpec spec, DateTime time, int hoursAgo) {
    final usual = _usual(time.hour);
    final random = Random(
      spec.seed * 1000003 + time.millisecondsSinceEpoch ~/ 3600000,
    );
    final values = {
      for (final e in usual.entries)
        e.key: e.value * (0.85 + random.nextDouble() * 0.3),
    };
    if (spec.pattern == _Pattern.estrus && hoursAgo <= 10) {
      values[Behavior.walk] = values[Behavior.walk]! * 3.2 + 6;
      values[Behavior.rest] = values[Behavior.rest]! * 0.6;
    }
    if (spec.pattern == _Pattern.lowRumination) {
      values[Behavior.ruminate] = values[Behavior.ruminate]! * 0.45;
      values[Behavior.eat] = values[Behavior.eat]! * 0.7;
    }
    final total = values.values.reduce((a, b) => a + b);
    final minutes = {
      for (final b in [Behavior.eat, Behavior.walk, Behavior.ruminate])
        b: (values[b]! / total * 60).round(),
    };
    minutes[Behavior.rest] = 60 - minutes.values.reduce((a, b) => a + b);
    return CowHour(
      time: time,
      minutes: minutes,
      usualActive: usual[Behavior.eat]! + usual[Behavior.walk]!,
    );
  }

  /// 時間帯ごとの、いつもの行動（分）
  static Map<Behavior, double> _usual(int hour) {
    final (rest, eat, walk, ruminate) = switch (hour) {
      < 6 => (40.0, 1.0, 1.0, 18.0),
      < 10 => (12.0, 30.0, 8.0, 10.0),
      < 16 => (25.0, 10.0, 5.0, 20.0),
      < 21 => (12.0, 28.0, 8.0, 12.0),
      _ => (35.0, 3.0, 2.0, 20.0),
    };
    return {
      Behavior.rest: rest,
      Behavior.eat: eat,
      Behavior.walk: walk,
      Behavior.ruminate: ruminate,
    };
  }

  @override
  Future<List<FarmAlert>> alerts() async {
    final now = _clock();
    final alerts = <FarmAlert>[];
    for (final cow in await cows()) {
      if (cow.flag != null) {
        final low = cow.flag == _Pattern.lowRumination.flag;
        alerts.add(
          FarmAlert(
            level: low ? AlertLevel.critical : AlertLevel.warning,
            kind: 'cow',
            targetId: cow.id,
            title: '${cow.id} ${cow.name}: ${cow.flag}',
            message: low ? '反すうの時間がいつもより減っています' : '歩く時間がいつもより増えています',
            time: cow.updatedAt,
          ),
        );
      }
      if (cow.battery < 20) {
        alerts.add(
          FarmAlert(
            level: AlertLevel.warning,
            kind: 'cow',
            targetId: cow.id,
            title: '${cow.id} ${cow.name}: 電池が少なくなっています',
            message: '首輪の電池の残りは ${cow.battery}% です',
            time: cow.updatedAt,
          ),
        );
      }
    }
    for (final s in await soilSensors()) {
      final status = s.statusAt(now);
      if (status == SoilStatus.good) continue;
      alerts.add(
        FarmAlert(
          level: AlertLevel.warning,
          kind: 'soil',
          targetId: s.id,
          title: '${s.name}: ${status.label}',
          message: status == SoilStatus.offline
              ? '${s.location}のセンサーからデータが届いていません'
              : '${s.location}の水分は ${s.moisture.toStringAsFixed(1)}% です',
          time: s.updatedAt,
        ),
      );
    }
    for (final s in await soilSensors()) {
      final status = s.temperatureStatusAt(now);
      if (status != SoilStatus.cold && status != SoilStatus.hot) continue;
      alerts.add(
        FarmAlert(
          level: AlertLevel.warning,
          kind: 'temperature',
          targetId: s.id,
          title: '${s.name}: ${status.label}',
          message:
              '${s.location}の土の温度は ${s.temperature!.toStringAsFixed(1)}℃ です',
          time: s.updatedAt,
        ),
      );
    }
    return alerts;
  }
}

class _SoilSpec {
  const _SoilSpec(
    this.id,
    this.name,
    this.location,
    this.moisture,
    this.temperature,
    this.battery,
    this.minutesAgo,
    this.dryBelow,
    this.wetAbove,
    this.hoursAgo,
  );

  final String id;
  final String name;
  final String location;
  final double moisture;
  final double? temperature;
  final int battery;
  final int minutesAgo;
  final double dryBelow;
  final double wetAbove;
  final int hoursAgo;

  SoilSensor sensor(DateTime now) => SoilSensor(
    id: id,
    name: name,
    location: location,
    moisture: moisture,
    temperature: temperature,
    battery: battery,
    updatedAt: now.subtract(Duration(hours: hoursAgo, minutes: minutesAgo)),
    dryBelow: dryBelow,
    wetAbove: wetAbove,
    coldBelow: 10,
    hotAbove: 30,
  );
}

enum _Pattern {
  normal(null),
  estrus('発情の候補'),
  lowRumination('体調確認の候補');

  const _Pattern(this.flag);
  final String? flag;
}

class _CowSpec {
  const _CowSpec(this.id, this.name, this.seed, this.battery, this.pattern);
  final String id;
  final String name;
  final int seed;
  final int battery;
  final _Pattern pattern;
}
