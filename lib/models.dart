/// アプリで扱うデータの形。受信機の API（docs/api.md）と対応している。
library;

/// 首輪が判定する牛の行動。並びはグラフの積み上げ順と同じ。
enum Behavior {
  rest('rest', '休息'),
  eat('eat', '採食'),
  walk('walk', '歩行'),
  ruminate('ruminate', '反すう');

  const Behavior(this.key, this.label);
  final String key;
  final String label;

  static Behavior fromKey(String key) => Behavior.values.firstWhere(
    (b) => b.key == key,
    orElse: () => throw FormatException('未知の行動: $key'),
  );
}

enum SoilStatus {
  dry('乾燥'),
  good('適正'),
  wet('過湿'),
  cold('低温'),
  hot('高温'),
  offline('通信なし');

  const SoilStatus(this.label);
  final String label;
}

enum AlertLevel { warning, critical }

/// これ以上データが来ていないセンサーは「通信なし」として扱う。
const offlineAfter = Duration(hours: 1);

class SoilSensor {
  const SoilSensor({
    required this.id,
    required this.name,
    required this.location,
    required this.moisture,
    required this.temperature,
    required this.battery,
    required this.updatedAt,
    required this.dryBelow,
    required this.wetAbove,
    required this.coldBelow,
    required this.hotAbove,
  });

  final String id;
  final String name;
  final String location;

  /// 土の水分（%）
  final double moisture;

  /// 土の温度（℃）。温度を測らないセンサーでは null。
  final double? temperature;

  /// 電池の残り（%）
  final int battery;
  final DateTime updatedAt;

  /// この値より下なら乾燥
  final double dryBelow;

  /// この値より上なら過湿
  final double wetAbove;

  /// この温度より下なら低温
  final double coldBelow;

  /// この温度より上なら高温
  final double hotAbove;

  /// 水分の状態
  SoilStatus statusAt(DateTime now) {
    if (now.difference(updatedAt) > offlineAfter) return SoilStatus.offline;
    if (moisture < dryBelow) return SoilStatus.dry;
    if (moisture > wetAbove) return SoilStatus.wet;
    return SoilStatus.good;
  }

  /// 温度の状態
  SoilStatus temperatureStatusAt(DateTime now) {
    final value = temperature;
    if (value == null || now.difference(updatedAt) > offlineAfter) {
      return SoilStatus.offline;
    }
    if (value < coldBelow) return SoilStatus.cold;
    if (value > hotAbove) return SoilStatus.hot;
    return SoilStatus.good;
  }

  factory SoilSensor.fromJson(Map<String, dynamic> j) => SoilSensor(
    id: j['id'] as String,
    name: j['name'] as String,
    location: j['location'] as String,
    moisture: (j['moisture'] as num).toDouble(),
    temperature: (j['temperature'] as num?)?.toDouble(),
    battery: (j['battery'] as num).toInt(),
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    dryBelow: (j['dry_below'] as num).toDouble(),
    wetAbove: (j['wet_above'] as num).toDouble(),
    coldBelow: (j['cold_below'] as num).toDouble(),
    hotAbove: (j['hot_above'] as num).toDouble(),
  );
}

class SoilPoint {
  const SoilPoint(this.time, this.moisture, this.temperature);
  final DateTime time;
  final double moisture;

  /// 温度を測らないセンサーでは null
  final double? temperature;

  factory SoilPoint.fromJson(Map<String, dynamic> j) => SoilPoint(
    DateTime.parse(j['time'] as String).toLocal(),
    (j['moisture'] as num).toDouble(),
    (j['temperature'] as num?)?.toDouble(),
  );
}

class SoilDetail {
  const SoilDetail(this.sensor, this.history);
  final SoilSensor sensor;
  final List<SoilPoint> history;
}

class Cow {
  const Cow({
    required this.id,
    required this.name,
    required this.current,
    required this.battery,
    required this.updatedAt,
    required this.last24h,
    required this.usualRuminate,
    this.flag,
  });

  final String id;
  final String name;

  /// 今の行動
  final Behavior current;
  final int battery;
  final DateTime updatedAt;

  /// 過去24時間の行動ごとの合計（分）
  final Map<Behavior, int> last24h;

  /// いつもの1日の反すう時間（分）
  final int usualRuminate;

  /// 「発情の候補」のような確認の知らせ。なければ null。
  final String? flag;

  factory Cow.fromJson(Map<String, dynamic> j) {
    final totals = j['last_24h'] as Map<String, dynamic>;
    return Cow(
      id: j['id'] as String,
      name: j['name'] as String,
      current: Behavior.fromKey(j['current'] as String),
      battery: (j['battery'] as num).toInt(),
      updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      last24h: {
        for (final b in Behavior.values) b: (totals[b.key] as num).toInt(),
      },
      usualRuminate: (j['usual_ruminate'] as num).toInt(),
      flag: j['flag'] as String?,
    );
  }
}

/// 1時間ぶんの行動の記録
class CowHour {
  const CowHour({
    required this.time,
    required this.minutes,
    required this.usualActive,
  });

  final DateTime time;
  final Map<Behavior, int> minutes;

  /// 同じ時間帯のいつもの活動量（分）
  final double usualActive;

  /// 活動量（分）。採食と歩行の合計。
  int get active => minutes[Behavior.eat]! + minutes[Behavior.walk]!;

  factory CowHour.fromJson(Map<String, dynamic> j) => CowHour(
    time: DateTime.parse(j['time'] as String).toLocal(),
    minutes: {for (final b in Behavior.values) b: (j[b.key] as num).toInt()},
    usualActive: (j['usual_active'] as num).toDouble(),
  );
}

class CowDetail {
  const CowDetail(this.cow, this.hours);
  final Cow cow;
  final List<CowHour> hours;
}

class FarmAlert {
  const FarmAlert({
    required this.level,
    required this.kind,
    required this.targetId,
    required this.title,
    required this.message,
    required this.time,
  });

  final AlertLevel level;

  /// 'soil'（水分）か 'temperature'（土の温度）か 'cow'
  final String kind;
  final String targetId;
  final String title;
  final String message;
  final DateTime time;

  factory FarmAlert.fromJson(Map<String, dynamic> j) => FarmAlert(
    level: j['level'] == 'critical' ? AlertLevel.critical : AlertLevel.warning,
    kind: j['kind'] as String,
    targetId: j['target_id'] as String,
    title: j['title'] as String,
    message: j['message'] as String,
    time: DateTime.parse(j['time'] as String).toLocal(),
  );
}
