import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

FlGridData _grid(BuildContext context, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    strokeWidth: 1,
  ),
);

TextStyle _axisStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

TextStyle _tooltipStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall!
        .copyWith(color: Theme.of(context).colorScheme.onInverseSurface);

FlTitlesData _titles(
  BuildContext context, {
  required double yInterval,
  required String yUnit,
  required double xInterval,
  required String Function(int index) xLabel,
}) {
  final style = _axisStyle(context);
  const none = AxisTitles();
  return FlTitlesData(
    topTitles: none,
    rightTitles: none,
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: yInterval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text('${value.round()}$yUnit', style: style),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: xInterval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(xLabel(value.round()), style: style),
        ),
      ),
    ),
  );
}

/// 土の水分や温度の折れ線。適正の範囲を帯で示す。
class SoilLineChart extends StatelessWidget {
  const SoilLineChart({
    super.key,
    required this.times,
    required this.values,
    required this.low,
    required this.high,
    required this.minY,
    required this.maxY,
    required this.interval,
    required this.unit,
  });

  final List<DateTime> times;
  final List<double> values;

  /// 適正の範囲
  final double low;
  final double high;
  final double minY;
  final double maxY;
  final double interval;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final longRange = times.length > 48;
    final band = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 14),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (times.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: _grid(context, interval),
          borderData: FlBorderData(show: false),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: low, y2: high, color: band),
            ],
          ),
          titlesData: _titles(
            context,
            yInterval: interval,
            yUnit: unit,
            xInterval: longRange ? 24 : 6,
            xLabel: (i) {
              if (i < 0 || i >= times.length) return '';
              final t = times[i];
              return longRange ? dateText(t) : '${t.hour}時';
            },
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${dateTimeText(times[s.x.round()])}\n'
                    '${s.y.toStringAsFixed(1)}$unit',
                    _tooltipStyle(context),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              color: lineColor(context),
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1時間ごとの行動の積み上げ棒
class BehaviorHoursChart extends StatelessWidget {
  const BehaviorHoursChart({super.key, required this.hours});

  final List<CowHour> hours;

  /// 色の境目のすき間（分）。高さ 200px で約 2px になる。
  static const _gap = 0.6;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 60,
          alignment: BarChartAlignment.spaceBetween,
          gridData: _grid(context, 20),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            context,
            yInterval: 20,
            yUnit: '分',
            xInterval: 1,
            xLabel: (i) {
              if (i < 0 || i >= hours.length || i % 6 != 0) return '';
              return '${hours[i].time.hour}時';
            },
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, _, _, _) {
                final hour = hours[group.x];
                final lines = [
                  '${hour.time.hour}時台',
                  for (final b in Behavior.values)
                    '${b.label} ${hour.minutes[b]}分',
                ];
                return BarTooltipItem(lines.join('\n'), _tooltipStyle(context));
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < hours.length; i++) _group(context, i),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _group(BuildContext context, int index) {
    var from = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final b in Behavior.values) {
      final to = from + hours[index].minutes[b]!;
      if (to - from > _gap) {
        items.add(
          BarChartRodStackItem(from, to - _gap, behaviorColor(context, b)),
        );
      }
      from = to;
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: 60,
          width: 8,
          color: Colors.transparent,
          rodStackItems: items,
          borderRadius: BorderRadius.zero,
        ),
      ],
    );
  }
}

/// 活動量を、いつもの同じ時間帯と比べる折れ線
class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.hours});

  final List<CowHour> hours;

  @override
  Widget build(BuildContext context) {
    final color = lineColor(context);
    final usualColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 14),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (hours.length - 1).toDouble(),
          minY: 0,
          maxY: 60,
          gridData: _grid(context, 20),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            context,
            yInterval: 20,
            yUnit: '分',
            xInterval: 6,
            xLabel: (i) =>
                i >= 0 && i < hours.length ? '${hours[i].time.hour}時' : '',
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    s.barIndex == 0
                        ? '${hours[s.x.round()].time.hour}時台 '
                              '実際 ${s.y.round()}分'
                        : 'いつも ${s.y.round()}分',
                    _tooltipStyle(context),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < hours.length; i++)
                  FlSpot(i.toDouble(), hours[i].active.toDouble()),
              ],
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: [
                for (var i = 0; i < hours.length; i++)
                  FlSpot(i.toDouble(), hours[i].usualActive),
              ],
              color: usualColor,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// 24時間の割合を1本で見せる棒。一覧のカードに使う。
class BehaviorShareBar extends StatelessWidget {
  const BehaviorShareBar({super.key, required this.totals});

  final Map<Behavior, int> totals;

  @override
  Widget build(BuildContext context) {
    final parts = Behavior.values.where((b) => totals[b]! > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          spacing: 2,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final b in parts)
              Expanded(
                flex: totals[b]!,
                child: ColoredBox(color: behaviorColor(context, b)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 凡例の1項目
class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: dashed ? 18 : 12,
          height: dashed ? 2 : 12,
          child: dashed
              ? Row(
                  spacing: 2,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(child: ColoredBox(color: color)),
                  ],
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 行動ごとの凡例。[totals] があれば合計時間も出す。
class BehaviorLegend extends StatelessWidget {
  const BehaviorLegend({super.key, this.totals});

  final Map<Behavior, int>? totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final b in Behavior.values)
          LegendItem(
            color: behaviorColor(context, b),
            label: totals == null
                ? b.label
                : '${b.label} ${durationText(totals![b]!)}',
          ),
      ],
    );
  }
}
