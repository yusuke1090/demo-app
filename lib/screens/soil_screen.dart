import 'package:flutter/material.dart';

import '../data/data_source.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class SoilScreen extends StatelessWidget {
  const SoilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoadView<List<SoilSensor>>(
      load: (source) => source.soilSensors(),
      builder: (context, sensors) {
        if (sensors.isEmpty) return [const Text('センサーがまだ登録されていません')];
        return [
          for (final s in sensors)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SensorCard(sensor: s),
            ),
        ];
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.sensor});

  final SoilSensor sensor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SoilDetailScreen(id: sensor.id),
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
                  StatusChip.soil(sensor.statusAt(now)),
                  const SizedBox(width: 12),
                  Text(
                    '${sensor.moisture.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RangeMeter(sensor: sensor),
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

/// 0〜100% の中で、今の値と適正の範囲を示す。
class _RangeMeter extends StatelessWidget {
  const _RangeMeter({required this.sensor});

  final SoilSensor sensor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(double percent) => width * percent.clamp(0, 100) / 100;
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
                left: x(sensor.dryBelow),
                width: x(sensor.wetAbove) - x(sensor.dryBelow),
                top: 4,
                height: 6,
                child: ColoredBox(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                left: (x(sensor.moisture) - 2).clamp(0, width - 4),
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
  const SoilDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<SoilDetailScreen> createState() => _SoilDetailScreenState();
}

class _SoilDetailScreenState extends State<SoilDetailScreen> {
  int _hours = 168;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('土の水分の記録')),
      body: LoadView<SoilDetail>(
        key: ValueKey(_hours),
        load: (DataSource source) =>
            source.soilDetail(widget.id, hours: _hours),
        builder: (context, data) => _body(context, data),
      ),
    );
  }

  List<Widget> _body(BuildContext context, SoilDetail data) {
    final theme = Theme.of(context);
    final s = data.sensor;
    final now = DateTime.now();
    return [
      Text('${s.name}（${s.location}）', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${s.moisture.toStringAsFixed(1)}%',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(width: 12),
          StatusChip.soil(s.statusAt(now)),
        ],
      ),
      MutedText(
        [
          if (s.temperature != null)
            '土の温度 ${s.temperature!.toStringAsFixed(1)}℃',
          '電池 ${s.battery}%',
          '${agoText(s.updatedAt, now)}に更新',
        ].join(' ・ '),
      ),
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
      if (data.history.length < 2)
        const Text('グラフにするだけの記録がまだありません')
      else ...[
        MoistureChart(
          points: data.history,
          dryBelow: s.dryBelow,
          wetAbove: s.wetAbove,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            LegendItem(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              label: '適正の範囲 ${s.dryBelow.round()}〜${s.wetAbove.round()}%',
            ),
          ],
        ),
        DataTableTile(
          headers: const ['日時', '水分'],
          rows: [
            for (final p in data.history.reversed.take(48))
              [dateTimeText(p.time), '${p.moisture.toStringAsFixed(1)}%'],
          ],
        ),
      ],
    ];
  }
}
