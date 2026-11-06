import 'dart:math';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// 土のセンサーで見る項目。水分と温度を別のタブで見る。
enum SoilMetric {
  moisture('土の水分', '%', 0, 100, 20),
  temperature('土の温度', '℃', 0, 40, 10);

  const SoilMetric(
    this.title,
    this.unit,
    this.scaleMin,
    this.scaleMax,
    this.interval,
  );

  final String title;
  final String unit;

  /// メーターとグラフの基本の範囲
  final double scaleMin;
  final double scaleMax;
  final double interval;

  double? current(SoilSensor s) =>
      this == moisture ? s.moisture : s.temperature;

  double? ofPoint(SoilPoint p) => this == moisture ? p.moisture : p.temperature;

  double low(SoilSensor s) => this == moisture ? s.dryBelow : s.coldBelow;

  double high(SoilSensor s) => this == moisture ? s.wetAbove : s.hotAbove;

  SoilStatus status(SoilSensor s, DateTime now) =>
      this == moisture ? s.statusAt(now) : s.temperatureStatusAt(now);

  String text(double value) => '${value.toStringAsFixed(1)}$unit';
}

class SoilScreen extends StatelessWidget {
  const SoilScreen({super.key, required this.metric});

  final SoilMetric metric;

  @override
  Widget build(BuildContext context) {
    return LoadView<List<SoilSensor>>(
      load: (source) => source.soilSensors(),
      builder: (context, sensors) {
        if (sensors.isEmpty) return [const Text('センサーがまだ登録されていません')];
        final shown = sensors.where((s) => metric.current(s) != null);
        final hidden = sensors.where((s) => metric.current(s) == null);
        return [
          for (final s in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SensorCard(sensor: s, metric: metric),
            ),
          if (hidden.isNotEmpty)
            MutedText(
              '${hidden.map((s) => s.name).join('、')}は'
              '${metric.title.substring(2)}を測っていません',
            ),
        ];
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.sensor, required this.metric});

  final SoilSensor sensor;
  final SoilMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SoilDetailScreen(id: sensor.id, metric: metric),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sensor.name, style: theme.textTheme.titleMedium),
                        MutedText(sensor.location),
                      ],
                    ),
                  ),
                  StatusChip.soil(metric.status(sensor, now)),
                  const SizedBox(width: 12),
                  Text(
                    metric.text(metric.current(sensor)!),
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RangeMeter(sensor: sensor, metric: metric),
              const SizedBox(height: 8),
              MutedText(
                '電池 ${sensor.battery}% ・ ${agoText(sensor.updatedAt, now)}に更新',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// メーターの範囲の中で、今の値と適正の範囲を示す。
class _RangeMeter extends StatelessWidget {
  const _RangeMeter({required this.sensor, required this.metric});

  final SoilSensor sensor;
  final SoilMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(double value) {
          final span = metric.scaleMax - metric.scaleMin;
          return width * ((value - metric.scaleMin) / span).clamp(0.0, 1.0);
        }

        return SizedBox(
          height: 14,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: x(metric.low(sensor)),
                width: x(metric.high(sensor)) - x(metric.low(sensor)),
                top: 4,
                height: 6,
                child: ColoredBox(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                left: (x(metric.current(sensor)!) - 2).clamp(0, width - 4),
                width: 4,
                top: 0,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SoilDetailScreen extends StatefulWidget {
  const SoilDetailScreen({
    super.key,
    required this.id,
    this.metric = SoilMetric.moisture,
  });

  final String id;
  final SoilMetric metric;

  @override
  State<SoilDetailScreen> createState() => _SoilDetailScreenState();
}

class _SoilDetailScreenState extends State<SoilDetailScreen> {
  int _hours = 168;

  SoilMetric get _metric => widget.metric;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_metric.title}の記録')),
      body: LoadView<SoilDetail>(
        key: ValueKey(_hours),
        load: (source) => source.soilDetail(widget.id, hours: _hours),
        builder: _body,
      ),
    );
  }

  List<Widget> _body(BuildContext context, SoilDetail data) {
    final theme = Theme.of(context);
    final s = data.sensor;
    final now = DateTime.now();
    final value = _metric.current(s);
    final points = data.history
        .where((p) => _metric.ofPoint(p) != null)
        .toList();
    final values = [for (final p in points) _metric.ofPoint(p)!];
    return [
      Text('${s.name}（${s.location}）', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      if (value != null)
        Row(
          children: [
            Text(_metric.text(value), style: theme.textTheme.displaySmall),
            const SizedBox(width: 12),
            StatusChip.soil(_metric.status(s, now)),
          ],
        ),
      MutedText('電池 ${s.battery}% ・ ${agoText(s.updatedAt, now)}に更新'),
      const SizedBox(height: 16),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 24, label: Text('24時間')),
          ButtonSegment(value: 168, label: Text('7日間')),
        ],
        selected: {_hours},
        onSelectionChanged: (v) => setState(() => _hours = v.first),
      ),
      const SizedBox(height: 16),
      if (points.length < 2)
        const Text('グラフにするだけの記録がまだありません')
      else ...[
        SoilLineChart(
          times: [for (final p in points) p.time],
          values: values,
          low: _metric.low(s),
          high: _metric.high(s),
          minY: _floor(min(_metric.scaleMin, values.reduce(min))),
          maxY: _ceil(max(_metric.scaleMax * 0.8, values.reduce(max))),
          interval: _metric.interval,
          unit: _metric.unit,
        ),
        const SizedBox(height: 8),
        LegendItem(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          label:
              '適正の範囲 ${_metric.low(s).round()}〜'
              '${_metric.high(s).round()}${_metric.unit}',
        ),
        DataTableTile(
          headers: ['日時', _metric.title.substring(2)],
          rows: [
            for (
              var i = points.length - 1;
              i >= 0 && i >= points.length - 48;
              i--
            )
              [dateTimeText(points[i].time), _metric.text(values[i])],
          ],
        ),
      ],
    ];
  }

  double _floor(double v) => (v / _metric.interval).floor() * _metric.interval;

  double _ceil(double v) => (v / _metric.interval).ceil() * _metric.interval;
}
