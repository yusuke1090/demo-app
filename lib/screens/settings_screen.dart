import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/data_source.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  bool _initialized = false;
  bool _testing = false;
  String? _result;
  bool _ok = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _url.text = AppScope.of(context).url;
      // Web 版は受信機から配信されるので、開いたページの場所を初めの値にする
      if (_url.text.isEmpty && kIsWeb && Uri.base.scheme.startsWith('http')) {
        _url.text = Uri.base.origin;
      }
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final state = AppScope.of(context);
    final url = AppState.normalizeUrl(_url.text);
    if (url == null) {
      setState(() {
        _ok = false;
        _result = '接続先の形が正しくありません。例: 192.168.3.50:8080';
      });
      return;
    }
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final name = await ApiDataSource(url).status();
      state.useReceiver(url);
      _url.text = url;
      _show(true, '「$name」に接続しました');
    } on DataException catch (e) {
      _show(false, '$e。設定は変えていません。');
    }
  }

  void _show(bool ok, String message) {
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = ok;
      _result = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('データの取得元', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(state.demo ? '今はデモデータを表示しています。' : '今は受信機（${state.url}）に接続しています。'),
        if (!state.demo) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              state.useDemo();
              setState(() => _result = null);
            },
            child: const Text('デモデータに戻す'),
          ),
        ],
        const SizedBox(height: 24),
        Text('受信機の接続先', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'IP アドレスとポート',
            hintText: '192.168.3.50:8080',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _testing ? null : _connect,
          child: Text(_testing ? '接続を確かめています…' : '接続する'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          StatusChipLine(ok: _ok, message: _result!),
        ],
        const SizedBox(height: 24),
        const MutedText(
          'スマホと受信機を同じ Wi-Fi につないでください。'
          '受信機の API は、リポジトリの docs/api.md にまとめています。',
        ),
      ],
    );
  }
}

class StatusChipLine extends StatelessWidget {
  const StatusChipLine({super.key, required this.ok, required this.message});

  final bool ok;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          size: 20,
          color: ok ? statusGood : statusCritical,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(message)),
      ],
    );
  }
}
