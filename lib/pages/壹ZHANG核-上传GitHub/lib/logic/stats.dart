import '../data/models/walnut.dart';
import '../data/models/item.dart';

class StatRow {
  final String type;
  final int count;
  final double amount;
  StatRow(this.type, this.count, this.amount);
}

class Stats {
  // 按类型汇总 数量 + 金额（结果/KPI 与品类分布用）
  static List<StatRow> byType(List<Walnut> walnuts, List<Item> items) {
    final map = <String, StatRow>{};
    void add(String type, double price) {
      final r = map.putIfAbsent(type, () => StatRow(type, 0, 0));
      map[type] = StatRow(type, r.count + 1, r.amount + price);
    }

    for (final w in walnuts) add('核桃', w.price);
    for (final it in items) add(it.type, it.price);
    return map.values.toList();
  }

  // 按月趋势（时间趋势用）：buy_date 取前 7 位 YYYY-MM 分组
  static List<({String month, int count, double amount})> byMonth(
      List<Walnut> walnuts, List<Item> items) {
    final map = <String, ({int count, double amount})>{};
    void add(String ym, double price) {
      final r = map[ym] ?? (count: 0, amount: 0.0);
      map[ym] = (count: r.count + 1, amount: r.amount + price);
    }

    for (final w in walnuts) {
      if (w.buyDate.length >= 7) add(w.buyDate.substring(0, 7), w.price);
    }
    for (final it in items) {
      if (it.buyDate.length >= 7) add(it.buyDate.substring(0, 7), it.price);
    }
    final months = map.keys.toList()..sort();
    return months
        .map((m) => (month: m, count: map[m]!.count, amount: map[m]!.amount))
        .toList();
  }

  static ({int totalCount, double totalAmount}) totals(
      List<Walnut> walnuts, List<Item> items) {
    var c = 0;
    var a = 0.0;
    for (final w in walnuts) {
      c += 1;
      a += w.price;
    }
    for (final it in items) {
      c += 1;
      a += it.price;
    }
    return (totalCount: c, totalAmount: a);
  }
}
