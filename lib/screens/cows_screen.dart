import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class CowsScreen extends StatelessWidget {
  const CowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Cow>>(
      load: (source) => source.cows(),
      builder: (context, cows) {
        if (cows.isEmpty) return [const Text('牛がまだ登録されていません')];
        return [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: BehaviorLegend(),
          ),
          for (final cow in cows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CowCard(cow: cow),
            ),
        ];
      },
    );
  }
}

class _CurrentBehavior extends StatelessWidget {
  const _CurrentBehavior({required this.behavior});

  final Behavior behavior;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(behaviorIcon(behavior), size: 18),
        const SizedBox(width: 4),
        Text(behavior.label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _CowCard extends StatelessWidget {
  const _CowCard({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CowDetailScreen(id: cow.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cow.id} ${cow.name}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _CurrentBehavior(behavior: cow.current),
                ],
              ),
              if (cow.flag != null) ...[
                const SizedBox(height: 6),
                StatusChip(
                  icon: Icons.warning_amber_rounded,
                  label: cow.flag!,
                  color: statusWarning,
                ),
              ],
              const SizedBox(height: 10),
              BehaviorShareBar(totals: cow.last24h),
              const SizedBox(height: 8),
              MutedText(
                '電池 ${cow.battery}% ・ ${agoText(cow.updatedAt, now)}に更新',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CowDetailScreen extends StatelessWidget {
  const CowDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('牛の行動の記録')),
      body: LoadView<CowDetail>(
        load: (source) => source.cowDetail(id),
        builder: _body,
      ),
    );
  }

  List<Widget> _body(BuildContext context, CowDetail data) {
    final theme = Theme.of(context);
    final cow = data.cow;
    final now = DateTime.now();
    final ruminate = cow.last24h[Behavior.ruminate]!;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '${cow.id} ${cow.name}',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          _CurrentBehavior(behavior: cow.current),
        ],
      ),
      MutedText('電池 ${cow.battery}% ・ ${agoText(cow.updatedAt, now)}に更新'),
      if (cow.flag != null) ...[
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: statusWarning,
            ),
            title: Text(cow.flag!),
            subtitle: const Text('診断ではなく、人が確認するための知らせです。最後の判断は管理者や獣医師が行います。'),
          ),
        ),
      ],
      const SectionTitle('過去24時間の行動'),
      BehaviorLegend(totals: cow.last24h),
      const SizedBox(height: 12),
      if (data.hours.isEmpty)
        const Text('記録がまだありません')
      else ...[
        BehaviorHoursChart(hours: data.hours),
        const SectionTitle('活動量（採食＋歩行）'),
        Wrap(
          spacing: 14,
          children: [
            LegendItem(color: lineColor(context), label: '実際'),
            LegendItem(
              color: theme.colorScheme.onSurfaceVariant,
              label: 'いつもの同じ時間帯',
              dashed: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ActivityChart(hours: data.hours),
        const SectionTitle('反すうの時間'),
        Text(durationText(ruminate), style: theme.textTheme.headlineMedium),
        MutedText('いつもは ${durationText(cow.usualRuminate)}'),
        const SizedBox(height: 8),
        DataTableTile(
          headers: ['時間', for (final b in Behavior.values) b.label, 'いつもの活動量'],
          rows: [
            for (final h in data.hours.reversed)
              [
                '${h.time.hour}時台',
                for (final b in Behavior.values) '${h.minutes[b]}分',
                '${h.usualActive.round()}分',
              ],
          ],
        ),
      ],
    ];
  }
}
