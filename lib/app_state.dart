import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/data_source.dart';
import 'data/demo_data_source.dart';

/// 接続先の設定と、今使っているデータの取得元を持つ。
class AppState extends ChangeNotifier {
  AppState({DataSource? source, SharedPreferences? prefs})
    : _source = source ?? DemoDataSource(),
      _prefs = prefs {
    final saved = prefs?.getString(_urlKey);
    if (saved != null) _url = saved;
    if (source == null &&
        prefs?.getBool(_demoKey) == false &&
        _url.isNotEmpty) {
      _demo = false;
      _source = ApiDataSource(_url);
    }
  }

  static const _urlKey = 'receiver_url';
  static const _demoKey = 'demo_mode';

  final SharedPreferences? _prefs;
  DataSource _source;
  bool _demo = true;
  String _url = '';

  DataSource get source => _source;
  bool get demo => _demo;
  String get url => _url;

  void useDemo() {
    _demo = true;
    _source = DemoDataSource();
    _prefs?.setBool(_demoKey, true);
    notifyListeners();
  }

  void useReceiver(String url) {
    _demo = false;
    _url = url;
    _source = ApiDataSource(url);
    _prefs?.setBool(_demoKey, false);
    _prefs?.setString(_urlKey, url);
    notifyListeners();
  }

  /// 入力された接続先を整える。使えない形なら null を返す。
  static String? normalizeUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return text.replaceFirst(RegExp(r'/+$'), '');
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
