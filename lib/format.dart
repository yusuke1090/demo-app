String _two(int n) => n.toString().padLeft(2, '0');

String timeText(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String dateText(DateTime t) => '${t.month}/${t.day}';

String dateTimeText(DateTime t) => '${dateText(t)} ${timeText(t)}';

/// 「3分前」のような書き方にする。
String agoText(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes}分前';
  if (d.inDays < 1) return '${d.inHours}時間前';
  return '${d.inDays}日前';
}

/// 分を「7時間20分」の形にする。
String durationText(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m分';
  if (m == 0) return '$h時間';
  return '$h時間$m分';
}
