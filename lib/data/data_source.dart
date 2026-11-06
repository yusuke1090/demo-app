import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

/// 画面に出すデータの取得元。デモと受信機を同じ形で扱う。
abstract class DataSource {
  Future<String> status();
  Future<List<SoilSensor>> soilSensors();
  Future<SoilDetail> soilDetail(String id, {int hours = 168});
  Future<List<Cow>> cows();
  Future<CowDetail> cowDetail(String id);
  Future<List<FarmAlert>> alerts();
}

class DataException implements Exception {
  const DataException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 受信機（ラズパイなど）から HTTP でデータを取る。
class ApiDataSource implements DataSource {
  ApiDataSource(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
    } on TimeoutException {
      throw const DataException('受信機から応答がありません');
    } on http.ClientException {
      throw const DataException('受信機に接続できません');
    }
    if (res.statusCode != 200) {
      throw DataException('受信機がエラーを返しました（${res.statusCode}）');
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const DataException('受信機の応答を読めませんでした');
    }
  }

  /// JSON の形が想定と違うときも、画面には分かる文で伝える。
  Future<T> _read<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final json = await _get(path);
    try {
      return parse(json);
    } on TypeError {
      throw const DataException('受信機の応答の形が違います');
    } on FormatException {
      throw const DataException('受信機の応答の形が違います');
    }
  }

  static List<Map<String, dynamic>> _list(Object? value) =>
      (value as List).cast<Map<String, dynamic>>();

  @override
  Future<String> status() => _read('/api/status', (j) => j['name'] as String);

  @override
  Future<List<SoilSensor>> soilSensors() => _read(
    '/api/soil',
    (j) => _list(j['sensors']).map(SoilSensor.fromJson).toList(),
  );

  @override
  Future<SoilDetail> soilDetail(String id, {int hours = 168}) => _read(
    '/api/soil/${Uri.encodeComponent(id)}?hours=$hours',
    (j) => SoilDetail(
      SoilSensor.fromJson(j['sensor'] as Map<String, dynamic>),
      _list(j['history']).map(SoilPoint.fromJson).toList(),
    ),
  );

  @override
  Future<List<Cow>> cows() =>
      _read('/api/cows', (j) => _list(j['cows']).map(Cow.fromJson).toList());

  @override
  Future<CowDetail> cowDetail(String id) => _read(
    '/api/cows/${Uri.encodeComponent(id)}',
    (j) => CowDetail(
      Cow.fromJson(j['cow'] as Map<String, dynamic>),
      _list(j['hours']).map(CowHour.fromJson).toList(),
    ),
  );

  @override
  Future<List<FarmAlert>> alerts() => _read(
    '/api/alerts',
    (j) => _list(j['alerts']).map(FarmAlert.fromJson).toList(),
  );
}
