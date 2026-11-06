import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/data_source.dart';
import '../models.dart';
import '../theme.dart';

/// データを読み込んで一覧を出す。引っぱって更新でき、1分ごとにも読み直す。
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});

  final Future<T> Function(DataSource source) load;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  static const _interval = Duration(minutes: 1);

  DataSource? _source;
  T? _data;
  String? _error;
  bool _loaded = false;
  int _request = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) => _reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = AppScope.of(context).source;
    if (!identical(source, _source)) {
      _source = source;
      _data = null;
      _error = null;
      _loaded = false;
      _reload();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ++_request;
    try {
      final data = await widget.load(_source!);
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _error = null;
        _loaded = true;
      });
    } on DataException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.message;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final data = _data;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null)
            _ErrorCard(
              message: _error!,
              hasOldData: data != null,
              onRetry: _reload,
            ),
          if (data != null) ...widget.builder(context, data),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.hasOldData,
    required this.onRetry,
  });

  final String message;
  final bool hasOldData;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasOldData
                  ? '前回読み込んだデータを表示しています。'
                  : '受信機の電源、同じ Wi-Fi につないでいるか、設定の接続先を確かめてください。',
              style: TextStyle(color: colors.onErrorContainer),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onRetry, child: const Text('もう一度')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状態の表示。色だけに頼らず、アイコンと文字を出す。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  factory StatusChip.soil(SoilStatus status) => switch (status) {
    SoilStatus.good => StatusChip(
      icon: Icons.check_circle,
      label: status.label,
      color: statusGood,
    ),
    SoilStatus.offline => StatusChip(
      icon: Icons.cloud_off,
      label: status.label,
      color: statusCritical,
    ),
    _ => StatusChip(
      icon: Icons.warning_amber_rounded,
      label: status.label,
      color: statusWarning,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// 電池と更新時刻など、補足の1行
class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 数値を表で見るための折りたたみ。色が見分けにくいときの代わりにもなる。
class DataTableTile extends StatelessWidget {
  const DataTableTile({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final bold = style?.copyWith(fontWeight: FontWeight.bold);
    return ExpansionTile(
      title: const Text('数値を表で見る'),
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      children: [
        Table(
          children: [
            TableRow(
              children: [
                for (final h in headers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(h, style: bold),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(cell, style: style),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
