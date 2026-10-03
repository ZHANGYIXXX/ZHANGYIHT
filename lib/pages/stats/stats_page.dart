import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/stats.dart';
import '../../logic/format.dart';
import '../../data/models/walnut.dart';
import '../../data/models/item.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});
  // 用 static：GlobalKey 作为滚动锚点无需每实例重建，且类是 const 构造
  // （Dart 要求 const 构造函数的类中，实例字段必须用常量初始化）
  static final _kResult = GlobalKey();
  static final _kTrend = GlobalKey();
  static final _kReason = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wn = ref.watch(walnutsProvider);
    final it = ref.watch(itemsProvider);
    return Scaffold(backgroundColor: Tokens.bg, body: SafeArea(child: wn.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (walnuts) => it.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (items) {
          final t = Stats.totals(walnuts, items);
          final byType = Stats.byType(walnuts, items);
          final byMonth = Stats.byMonth(walnuts, items);
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('收藏统计', style: TextStyle(fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold, color: Tokens.text)),
            const SizedBox(height: 12),
            _anchorBar(),
            const SizedBox(height: 12),
            _kpi(t.totalCount, t.totalAmount),
            const SizedBox(height: 16),
            _block(_kResult, '结果 · 品类分布', _byType(byType)),
            _block(_kTrend, '趋势 · 按月', _byMonth(byMonth)),
            _block(_kReason, '原因 · 洞察', _insights(walnuts, items, byType, t)),
            const SizedBox(height: 24),
          ]);
        },
      ),
    )));
  }

  Widget _anchorBar() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
    NeuChip(label: '结果', onTap: () => _jump(_kResult)),
    const SizedBox(width: 10),
    NeuChip(label: '趋势', onTap: () => _jump(_kTrend)),
    const SizedBox(width: 10),
    NeuChip(label: '原因', onTap: () => _jump(_kReason)),
  ]));

  void _jump(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0);
    }
  }

  Widget _kpi(int count, double amount) => Row(children: [
    Expanded(child: _kpiCard('总件数', '$count', Tokens.accent)),
    const SizedBox(width: 14),
    Expanded(child: _kpiCard('总价值', formatPrice(amount), Tokens.accent)),
  ]);
  Widget _kpiCard(String k, String v, Color c) => NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(18), child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
      const SizedBox(height: 8),
      Text(v, style: TextStyle(color: c, fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold)),
    ]));

  Widget _block(GlobalKey k, String title, Widget child) => Container(key: k, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint, fontWeight: FontWeight.w700))),
    NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child: child),
    const SizedBox(height: 16),
  ]));

  Widget _byType(List<StatRow> rows) {
    if (rows.isEmpty) return const Text('暂无数据', style: TextStyle(color: Tokens.faint));
    final max = rows.map((r) => r.amount).reduce((a, b) => a > b ? a : b);
    return Column(children: rows.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(r.type, style: const TextStyle(color: Tokens.text)), const Spacer(), Text('${r.count}件 · ${formatPrice(r.amount)}', style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint))]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(height: 10, color: Tokens.bg, child: Row(children: [Expanded(flex: max > 0 ? (r.amount / max * 100).round() : 0, child: Container(decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(8)))) , Expanded(flex: 1, child: Container())]))),
    ]))).toList());
  }

  Widget _byMonth(List<({String month, int count, double amount})> rows) {
    if (rows.isEmpty) return const Text('暂无数据', style: TextStyle(color: Tokens.faint));
    final max = rows.map((r) => r.amount).reduce((a, b) => a > b ? a : b);
    return Column(children: rows.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(r.month, style: const TextStyle(color: Tokens.text)), const Spacer(), Text('${r.count}件 · ${formatPrice(r.amount)}', style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint))]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(height: 10, color: Tokens.bg, child: Row(children: [Expanded(flex: max > 0 ? (r.amount / max * 100).round() : 0, child: Container(decoration: BoxDecoration(color: Tokens.accentSoft, borderRadius: BorderRadius.circular(8)))) , Expanded(flex: 1, child: Container())]))),
    ]))).toList());
  }

  Widget _insights(List<Walnut> walnuts, List<Item> items, List<StatRow> byType, dynamic t) {
    final full = walnuts.where((w) => w.full).length;
    final repaired = walnuts.where((w) => w.repaired).length;
    final yellow = walnuts.where((w) => w.yellow).length;
    final top = [...walnuts.map((w) => (name: w.name, price: w.price)), ...items.map((i) => (name: i.type, price: i.price))]
        .where((e) => e.price > 0).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _insight('核桃品相', '全品 $full · 有修 $repaired · 有黄 $yellow'),
      if (top.isNotEmpty) _insight('最贵的一件', '${top.first.name} · ${formatPrice(top.first.price)}'),
      _insight('品类数', '核桃 ${walnuts.length} 件 · 其他 ${items.length} 件'),
    ]);
  }

  Widget _insight(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Text(k, style: const TextStyle(color: Tokens.muted)), const Spacer(), Text(v, style: const TextStyle(color: Tokens.text, fontWeight: FontWeight.w600))]));
}
