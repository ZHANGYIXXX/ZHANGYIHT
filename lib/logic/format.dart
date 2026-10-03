// 展示用格式化辅助

String formatPrice(double p) {
  if (p == p.truncateToDouble()) return '¥${p.toInt()}';
  return '¥${p.toStringAsFixed(2)}';
}

String formatSize(double mm) => mm > 0 ? '${mm.toStringAsFixed(1)} mm' : '—';

String formatWeight(double w) => w > 0 ? '${w.toStringAsFixed(1)} g' : '—';

// 品相标签（仅核桃）
List<String> patinaTags({required bool full, required bool repaired, required bool yellow}) {
  final tags = <String>[];
  if (full) tags.add('全品');
  if (repaired) tags.add('有修');
  if (yellow) tags.add('有黄');
  if (tags.isEmpty) tags.add('未标注');
  return tags;
}
