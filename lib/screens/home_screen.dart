import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/data_source.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cows_screen.dart';
import 'soil_screen.dart';

class _Overview {
  const _Overview(this.sensors, this.cows, this.alerts);
  final List<SoilSensor> sensors;
  final List<Cow> cows;
  final List<FarmAlert> alerts;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  static Future<_Overview> _load(DataSource source) async {
    // 順に読むと、失敗したときの DataException がそのまま画面に届く
    return _Overview(
      await source.soilSensors(),
      await source.cows(),
      await source.alerts(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    return LoadView<_Overview>(
      load: _load,
      builder: (context, data) {
        final now = DateTime.now();
        final goodSoil = data.sensors
            .where((s) => s.statusAt(now) == SoilStatus.good)
            .length;
        final flagged = data.cows.where((c) => c.flag != null).length;
        return [
          if (demo) const _DemoBanner(),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.water_drop_outlined,
                  title: '土の水分',
                  value: '$goodSoil / ${data.sensors.length}',
                  note: '適正のセンサー',
                  onTap: () => onOpenTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.pets_outlined,
                  title: '牛の行動',
                  value: '$flagged 頭',
                  note: '${data.cows.length}頭のうち確認の候補',
                  onTap: () => onOpenTab(2),
                ),
              ),
            ],
          ),
          const SectionTitle('確認すること'),
          if (data.alerts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle, color: statusGood),
                title: Text('今は確認することはありません'),
              ),
            )
          else
            for (final alert in _sorted(data.alerts))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertCard(alert: alert, now: now),
              ),
          const SizedBox(height: 8),
          MutedText('${timeText(now)} に更新'),
        ];
      },
    );
  }

  static List<FarmAlert> _sorted(List<FarmAlert> alerts) => [
    ...alerts.where((a) => a.level == AlertLevel.critical),
    ...alerts.where((a) => a.level != AlertLevel.critical),
  ];
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          const Expanded(child: MutedText('デモデータを表示中です。実機の値ではありません。')),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(title, style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineMedium),
              MutedText(note),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.now});

  final FarmAlert alert;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final critical = alert.level == AlertLevel.critical;
    return Card(
      child: ListTile(
        leading: Icon(
          critical ? Icons.error_outline : Icons.warning_amber_rounded,
          color: critical ? statusCritical : statusWarning,
        ),
        title: Text(alert.title),
        subtitle: Text('${alert.message}（${agoText(alert.time, now)}）'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => alert.kind == 'cow'
                ? CowDetailScreen(id: alert.targetId)
                : SoilDetailScreen(id: alert.targetId),
          ),
        ),
      ),
    );
  }
}
