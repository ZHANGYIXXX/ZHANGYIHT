import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/stats.dart';
import '../../logic/format.dart';
import '../../data/models/walnut.dart';
import '../../data/models/item.dart';
import '../../data/models/enums.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});
  // 锚点滚动目标
  static final _kKpi = GlobalKey();
  static final _kTrend = GlobalKey();
  static final _kDist = GlobalKey();
  static final _kDetail = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wn = ref.watch(walnutsProvider);
    final it = ref.watch(itemsProvider);
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: wn.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (walnuts) => it.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (items) => _StatsBody(walnuts: walnuts, items: items),
          ),
        ),
      ),
    );
  }
}

/// 统计内容（有状态：记录当前选中的明细行，点击刷新单项卡片）
class _StatsBody extends StatefulWidget {
  final List<Walnut> walnuts;
  final List<Item> items;
  const _StatsBody({required this.walnuts, required this.items});
  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  String _sel = '';

  // 类型顺序：核桃 + 其他四类（照原型 TYPES）
  static const List<String> _order = ['核桃', ...itemTypes];

  static const List<Color> _shades = [
    Color(0xFF51618A),
    Color(0xFF6F7FAE),
    Color(0xFF8A98C4),
    Color(0xFFA6B3D6),
    Color(0xFFC6CFE4),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Stats.totals(widget.walnuts, widget.items);
    final byTypeAll = Stats.byType(widget.walnuts, widget.items);
    final map = {for (final r in byTypeAll) r.type: r};
    final byType = _order
        .map((tp) => map[tp] ?? StatRow(tp, 0, 0))
        .toList();
    final byMonth = Stats.byMonth(widget.walnuts, widget.items);

    final anchor = _StatAnchor(
      onJump: (k) {
        final c = k.currentContext;
        if (c != null)
          Scrollable.ensureVisible(c,
              duration: const Duration(milliseconds: 300), alignment: 0);
      },
      keys: [
        (StatsPage._kKpi, '核心结果'),
        (StatsPage._kTrend, '时间趋势'),
        (StatsPage._kDist, '品类分布'),
        (StatsPage._kDetail, '明细'),
      ],
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _anchorBar(anchor)),
        SliverToBoxAdapter(
            child: Container(key: StatsPage._kKpi, child: _kpi(t.totalCount, t.totalAmount))),
        SliverToBoxAdapter(
            child: Container(key: StatsPage._kTrend, child: _trend(byMonth, byType))),
        SliverToBoxAdapter(
            child: Container(
                key: StatsPage._kDist, child: _dist(byType, t.totalAmount))),
        SliverToBoxAdapter(
            child: Container(
                key: StatsPage._kDetail,
                child: _detail(byType, t.totalAmount))),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _anchorBar(Widget anchor) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: anchor,
      );

  /// 区块外壳：照原型 .stat-sec（圆角20 / padding16 / margin-bottom14）
  Widget _sec(String title, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        child: NeumorphicBox(
          radius: Tokens.rCard,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: Tokens.fsBody,
                        fontWeight: FontWeight.w700,
                        color: Tokens.text)),
              ),
              child,
            ],
          ),
        ),
      );

  /// ① 核心结果（KPI）
  Widget _kpi(int count, double amount) => _sec(
        '核心结果',
        Row(children: [
          Expanded(child: _kpiBox('总购入数量', '$count 件')),
          const SizedBox(width: 14),
          Expanded(child: _kpiBox('总花费金额', formatPrice(amount))),
        ]),
      );

  Widget _kpiBox(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
          const SizedBox(height: 8),
          Text(v,
              style: TextStyle(
                  color: Tokens.accent,
                  fontSize: Tokens.fsEmph,
                  fontWeight: FontWeight.bold,
                  fontFamily: Tokens.fontNum)),
        ],
      );

  /// ② 时间趋势（按月）：件数柱状 + 金额折线
  Widget _trend(List<({String month, int count, double amount})> rows, List<StatRow> byType) {
    final byAmt = List<StatRow>.from(byType)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top3 = byAmt.take(3).map((r) =>
        '${r.type} ${formatPrice(r.amount)}（${r.amount > 0 ? ((r.amount / byAmt.fold(0.0, (s, e) => s + e.amount)) * 100).round() : 0}%）');
    return _sec(
      '时间趋势（按月）',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend([('购入件数', Tokens.accent), ('花费金额', Tokens.accentSoft)]),
          const SizedBox(height: 6),
          const Text('购入件数',
              style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700, fontSize: Tokens.fsHint)),
          const SizedBox(height: 6),
          _Bars(
            rows
                .map((r) => (r.month.substring(5) + '月', r.count.toDouble(), Tokens.accent))
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text('花费金额',
              style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700, fontSize: Tokens.fsHint)),
          const SizedBox(height: 6),
          _Line(
            rows
                .map((r) => (r.month.substring(5) + '月', r.amount))
                .toList(),
          ),
          if (top3.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Tokens.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Text('费用主要花在：${top3.join(' · ')}',
                  style: const TextStyle(color: Tokens.text, fontSize: Tokens.fsHint, height: 1.7)),
            ),
        ],
      ),
    );
  }

  Widget _legend(List<(String, Color)> items) => Row(
        children: [
          for (final (label, color) in items) ...[
            Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsLabel)),
            const SizedBox(width: 16),
          ],
        ],
      );

  /// ③ 品类分布：A 横向条形对照 + B 环形（金额占比）+ 条形（数量）
  Widget _dist(List<StatRow> byType, double totalAmount) {
    final maxQ = byType.map((r) => r.count).fold(0, (a, b) => a > b ? a : b).toDouble();
    final maxA = byType.map((r) => r.amount).fold(0.0, (a, b) => a > b ? a : b);
    return _sec(
      '品类分布',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A · 横向条形对照',
              style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700, fontSize: Tokens.fsHint)),
          _legend([('数量', Tokens.accent), ('金额', Tokens.accentSoft)]),
          const SizedBox(height: 6),
          for (final r in byType) _hBar(r.type, r.count.toDouble(), r.amount, maxQ, maxA),
          const SizedBox(height: 14),
          const Text('B · 环形（金额占比）+ 条形（数量）',
              style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700, fontSize: Tokens.fsHint)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Donut(byType, totalAmount),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < byType.length; i++) ...[
                      Row(children: [
                        Container(width: 11, height: 11, decoration: BoxDecoration(color: _shades[i % _shades.length], borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(child: Text(byType[i].type, style: const TextStyle(color: Tokens.text, fontSize: Tokens.fsHint))),
                        Text('${totalAmount > 0 ? ((byType[i].amount / totalAmount) * 100).round() : 0}%',
                            style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
                      ]),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hBar(String label, double q, double a, double maxQ, double maxA) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(color: Tokens.text)),
              const Spacer(),
              Text('${q.round()}件 · ${formatPrice(a)}',
                  style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 10,
                color: Tokens.bg,
                child: Row(children: [
                  Expanded(
                      flex: maxQ > 0 ? (q / maxQ * 100).round() : 0,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Tokens.accent, borderRadius: BorderRadius.circular(8)))),
                  Expanded(flex: 1, child: Container()),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 8,
                color: Tokens.bg,
                child: Row(children: [
                  Expanded(
                      flex: maxA > 0 ? (a / maxA * 100).round() : 0,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Tokens.accentSoft, borderRadius: BorderRadius.circular(8)))),
                  Expanded(flex: 1, child: Container()),
                ]),
              ),
            ),
          ],
        ),
      );

  /// ④ 明细表：点行定位单项原因
  Widget _detail(List<StatRow> byType, double totalAmount) {
    final total = byType.fold(0, (s, r) => s + r.count);
    final totalA = byType.fold(0.0, (s, r) => s + r.amount);
    return _sec(
      '明细（点击行定位原因）',
      Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFD2DAE6), width: 2))),
            child: const Row(children: [
              Expanded(flex: 2, child: Text('品类', style: TextStyle(color: Tokens.muted, fontWeight: FontWeight.w700))),
              Expanded(child: Text('件数', style: TextStyle(color: Tokens.muted, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              Expanded(child: Text('金额', style: TextStyle(color: Tokens.muted, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              Expanded(child: Text('占比', style: TextStyle(color: Tokens.muted, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
            ]),
          ),
          for (final r in byType)
            GestureDetector(
              onTap: () => setState(() => _sel = _sel == r.type ? '' : r.type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFDCE3EC), width: 1))),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(r.type, style: const TextStyle(color: Tokens.text))),
                  Expanded(child: Text('${r.count}', style: TextStyle(color: Tokens.text, fontFamily: Tokens.fontNum), textAlign: TextAlign.right)),
                  Expanded(child: Text(formatPrice(r.amount), style: TextStyle(color: Tokens.text, fontFamily: Tokens.fontNum), textAlign: TextAlign.right)),
                  Expanded(child: Text('${totalA > 0 ? ((r.amount / totalA) * 100).round() : 0}%', style: const TextStyle(color: Tokens.muted), textAlign: TextAlign.right)),
                ]),
              ),
            ),
          if (_sel.isNotEmpty)
            _single(byType.firstWhere((r) => r.type == _sel,
                orElse: () => StatRow(_sel, 0, 0)), total, totalA),
        ],
      ),
    );
  }

  Widget _single(StatRow r, int total, double totalA) => Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: Tokens.accentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.type} · 单项统计',
                style: const TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700, fontSize: Tokens.fsBody)),
            const SizedBox(height: 6),
            Text('购入 ${r.count} 件 · 花费 ${formatPrice(r.amount)} · 占总数 ${total > 0 ? ((r.count / total) * 100).round() : 0}% / 总金额 ${totalA > 0 ? ((r.amount / totalA) * 100).round() : 0}%',
                style: const TextStyle(color: Tokens.text, fontSize: Tokens.fsHint, height: 1.6)),
          ],
        ),
      );
}

/// 锚点导航条（核心结果/时间趋势/品类分布/明细）
class _StatAnchor extends StatelessWidget {
  final void Function(GlobalKey) onJump;
  final List<(GlobalKey, String)> keys;
  const _StatAnchor({required this.onJump, required this.keys});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (k, label) in keys)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onJump(k),
                child: NeumorphicBox(
                  state: NeuState.inset,
                  radius: Tokens.rPill,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(label,
                      style: const TextStyle(
                          color: Tokens.muted,
                          fontSize: Tokens.fsHint,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ]),
      );
}

/// 柱状图（购入件数）
class _Bars extends StatelessWidget {
  final List<(String, double, Color)> bars;
  const _Bars(this.bars);
  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty)
      return const Text('暂无数据', style: TextStyle(color: Tokens.faint));
    final maxV = bars.map((b) => b.$2).reduce((a, b) => a > b ? a : b);
    return LayoutBuilder(builder: (c, cons) {
      final w = cons.maxWidth;
      final n = bars.length;
      final slot = w / n;
      final bw = (slot * 0.5).clamp(8.0, 40.0);
      return SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (label, value, color) in bars)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(value.round().toString(),
                        style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsLabel)),
                    const SizedBox(height: 4),
                    Container(
                        width: bw,
                        height: maxV > 0 ? (value / maxV) * 90 : 0,
                        decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Text(label,
                        style: const TextStyle(color: Tokens.faint, fontSize: Tokens.fsLabel)),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// 折线图（花费金额）
class _Line extends StatelessWidget {
  final List<(String, double)> pts;
  const _Line(this.pts);
  @override
  Widget build(BuildContext context) {
    if (pts.isEmpty)
      return const Text('暂无数据', style: TextStyle(color: Tokens.faint));
    final maxV = pts.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
    return LayoutBuilder(builder: (c, cons) {
      final w = cons.maxWidth;
      final n = pts.length;
      final h = 130.0;
      final pad = 24.0;
      final plotW = math.max(1.0, w - pad * 2);
      final slot = n > 1 ? plotW / (n - 1) : 0.0;
      final points = <Offset>[];
      for (var i = 0; i < n; i++) {
        final x = pad + (n == 1 ? plotW / 2 : slot * i);
        final y = h - pad - (maxV > 0 ? (pts[i].$2 / maxV) * (h - pad * 2) : 0);
        points.add(Offset(x, y));
      }
      return SizedBox(
        height: h,
        child: Stack(children: [
          CustomPaint(size: Size(w, h), painter: _LinePainter(points)),
          for (var i = 0; i < n; i++)
            Positioned(
              left: points[i].dx - 4,
              top: points[i].dy - 4,
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: Tokens.accent, borderRadius: BorderRadius.circular(4))),
            ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: points[i].dx - 14,
              top: h - 16,
              child: Text(pts[i].$1,
                  style: const TextStyle(color: Tokens.faint, fontSize: Tokens.fsLabel)),
            ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: points[i].dx - 12,
              top: math.max(0, points[i].dy - 18),
              child: Text(pts[i].$2.round().toString(),
                  style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsLabel)),
            ),
        ]),
      );
    });
  }
}

class _LinePainter extends CustomPainter {
  final List<Offset> pts;
  _LinePainter(this.pts);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final p = Paint()
      ..color = Tokens.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) path.lineTo(o.dx, o.dy);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => o.pts != pts;
}

/// 环形图（金额占比）
class _Donut extends StatelessWidget {
  final List<StatRow> segs;
  final double total;
  const _Donut(this.segs, this.total);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(children: [
        CustomPaint(
          size: const Size(120, 120),
          painter: _DonutPainter(segs, total),
        ),
        const Center(
          child: Text('金额\n占比',
              textAlign: TextAlign.center,
              style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsLabel, height: 1.3)),
        ),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<StatRow> segs;
  final double total;
  _DonutPainter(this.segs, this.total);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;
    final sw = 14.0;
    final bg = Paint()
      ..color = Tokens.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    canvas.drawCircle(Offset(cx, cy), r, bg);
    if (total <= 0) return;
    var acc = -math.pi / 2;
    for (var i = 0; i < segs.length; i++) {
      final v = segs[i].amount;
      final frac = v / total;
      if (frac <= 0) continue;
      final a = frac * 2 * math.pi;
      final p = Paint()
        ..color = _StatsBodyState._shades[i % _StatsBodyState._shades.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), acc, a, false, p);
      acc += a;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.segs != segs || o.total != total;
}
