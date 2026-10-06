// 展示用格式化辅助

String formatPrice(double p) {
  if (p == p.truncateToDouble()) return '¥${p.toInt()}';
  return '¥${p.toStringAsFixed(2)}';
}

String formatSize(double mm) => mm > 0 ? '${mm.toStringAsFixed(1)} mm' : '—';

String formatWeight(double w) => w > 0 ? '${w.toStringAsFixed(1)} g' : '—';

/// 盘玩天数：从购买日期算到今天（含当天），日期无效返回 0
int calcDays(String buyDate) {
  final d = DateTime.tryParse(buyDate.trim());
  if (d == null) return 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = DateTime(d.year, d.month, d.day);
  final n = today.difference(from).inDays + 1;
  return n < 0 ? 0 : n;
}

/// 盘玩时长文案：如「已盘玩 128 天」
String formatDays(String buyDate) {
  final n = calcDays(buyDate);
  if (n <= 0) return '盘玩天数 —';
  if (n < 30) return '已盘玩 $n 天';
  if (n < 365) {
    final months = n ~/ 30;
    final days = n % 30;
    return days == 0 ? '已盘玩 $months 个月' : '已盘玩 $months 个月 $days 天';
  }
  return '已盘玩 ${(n / 365).floor()} 年 ${((n % 365) / 30).floor()} 个月';
}

// 品相标签（仅核桃）
List<String> patinaTags({required bool full, required bool repaired, required bool yellow}) {
  final tags = <String>[];
  if (full) tags.add('全品');
  if (repaired) tags.add('有修');
  if (yellow) tags.add('有黄');
  if (tags.isEmpty) tags.add('未标注');
  return tags;
}
