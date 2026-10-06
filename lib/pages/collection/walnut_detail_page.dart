import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/format.dart';
import '../../data/models/walnut.dart';
import '../../data/models/patina.dart';
import '../../logic/delete_helper.dart';
import '../../widgets/cover_carousel.dart';
import '../../widgets/image_viewer.dart';
import 'add_patina_page.dart';
import 'add_walnut_sheet.dart';

/// 身份卡（CI 反馈 #6 对齐定稿原型）：
/// 顶部图片自动流转 → 名称/编号/盘玩天数 → 价格 → 六面尺寸 → 重量
/// → 购买日期 → 入手平台 → 商家 → 备注 → 走色时间轴
///
/// 评审意见 P0 第一层：只收 id，数据经 walnutByIdProvider 按 id 取数，
/// 编辑/加走色后 ref.invalidate 自动刷新，根除 B4「编辑后看到旧值」。
class WalnutDetailPage extends ConsumerWidget {
  final int id;
  const WalnutDetailPage(this.id, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walnut = ref.watch(walnutByIdProvider(id));
    final patinae = ref.watch(patinaByWalnutProvider(id));
    return walnut.when(
      loading: () => _frame(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _frame(Center(child: Text('加载失败: $e'))),
      data: (w) {
        if (w == null) {
          return _frame(const Center(child: Text('未找到该藏品')));
        }
        return patinae.when(
          loading: () => _frame(const Center(child: CircularProgressIndicator())),
          error: (e, _) => _frame(Center(child: Text('加载失败: $e'))),
          data: (patinas) => _scaffold(context, ref, w, patinas),
        );
      },
    );
  }

  Widget _frame(Widget child) =>
      Scaffold(backgroundColor: Tokens.bg, body: SafeArea(child: child));

  Widget _scaffold(
      BuildContext context, WidgetRef ref, Walnut w, List<Patina> patinas) {
    final rels = <String>[
      if (w.coverPath.isNotEmpty) w.coverPath,
      for (final p in patinas) ...p.images,
    ];
    return Scaffold(
      backgroundColor: Tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: Tokens.text)),
        title: Text(w.name, style: TextStyle(color: Tokens.text)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _addPatina(context, ref, w),
              child: NeumorphicBox(
                state: NeuState.inset,
                radius: Tokens.rBtn,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                child: Row(children: [
                  Icon(Icons.add, size: 16, color: Tokens.seal),
                  const SizedBox(width: 3),
                  Text('走色',
                      style: TextStyle(
                          fontSize: Tokens.fsHint,
                          fontWeight: FontWeight.w700,
                          color: Tokens.seal)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CoverCarousel(rels: rels),
            const SizedBox(height: 14),
            _titleCard(w),
            const SizedBox(height: 16),
            _tagsRow(w),
            const SizedBox(height: 16),
            _section('尺寸（六面 / mm）', [
              _sizeRow('左', w.lBian, w.lDu, w.lGao),
              _sizeRow('右', w.rBian, w.rDu, w.rGao),
            ]),
            _section('重量', [_kv('', formatWeight(w.weight))]),
            _section('入手信息', [
              _kv('购买日期', w.buyDate),
              _kv('入手平台', w.channel.isEmpty ? '—' : w.channel),
              _kv('商家', w.merchant.isEmpty ? '—' : w.merchant),
            ]),
            _section('备注', [_kv('', w.remark.isEmpty ? '—' : w.remark)]),
            _timeline(context, ref, w, patinas),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _confirmDelete(context, ref, w),
              child: NeumorphicBox(
                  state: NeuState.raised,
                  radius: Tokens.rBtn,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: Text('删除这件',
                          style: TextStyle(
                              color: Tokens.badD10,
                              fontWeight: FontWeight.w700)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _edit(context, ref, w),
              child: NeumorphicBox(
                  state: NeuState.raised,
                  radius: Tokens.rBtn,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: Text('编辑资料',
                          style: TextStyle(
                              color: Tokens.accent,
                              fontWeight: FontWeight.w700)))),
            ),
          ],
        ),
      ),
    );
  }

  /// 名称 / 品类·品种 / 编号 / 盘玩天数 / 价格
  Widget _titleCard(Walnut w) => NeumorphicBox(
        radius: Tokens.rCard,
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.name,
                  style: TextStyle(
                      fontSize: Tokens.fsEmph,
                      fontWeight: FontWeight.bold,
                      color: Tokens.text)),
              const SizedBox(height: 6),
              Text('${w.category} · ${w.variety}',
                  style: TextStyle(color: Tokens.muted)),
              const SizedBox(height: 8),
              Row(children: [
                Text(w.code,
                    style: TextStyle(
                        color: Tokens.faint, fontSize: Tokens.fsHint)),
                const Spacer(),
                _dayBadge(w),
              ]),
              const SizedBox(height: 10),
              Text(formatPrice(w.price),
                  style: TextStyle(
                      fontSize: Tokens.fsEmph,
                      color: Tokens.seal,
                      fontWeight: FontWeight.w700)),
            ]),
      );

  Widget _dayBadge(Walnut w) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Tokens.accentSoft,
          borderRadius: BorderRadius.circular(Tokens.rPill),
          border: Border.all(color: Tokens.gold, width: 1),
        ),
        child: Text(formatDays(w.buyDate),
            style: TextStyle(
                fontSize: Tokens.fsLabel,
                color: Tokens.seal,
                fontWeight: FontWeight.w700)),
      );

  Widget _tagsRow(Walnut w) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: patinaTags(
              full: w.full, repaired: w.repaired, yellow: w.yellow)
          .map((t) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: Tokens.accentSoft,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(t,
                  style: TextStyle(
                      color: Tokens.accent, fontSize: Tokens.fsHint))))
          .toList());

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title,
                  style: TextStyle(
                      fontSize: Tokens.fsHint,
                      color: Tokens.muted,
                      fontWeight: FontWeight.w700))),
          NeumorphicBox(
              radius: Tokens.rCard,
              padding: const EdgeInsets.all(16),
              child: Column(children: children)),
          const SizedBox(height: 16),
        ],
      );

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        if (k.isNotEmpty)
          Text(k,
              style:
                  TextStyle(color: Tokens.muted, fontSize: Tokens.fsBody)),
        if (k.isNotEmpty) const Spacer(),
        Expanded(
            child: Text(v,
                style:
                    TextStyle(color: Tokens.text, fontSize: Tokens.fsBody),
                textAlign: k.isEmpty ? TextAlign.left : TextAlign.right)),
      ]));

  Widget _sizeRow(String side, double bian, double du, double gao) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(side, style: TextStyle(color: Tokens.muted)),
        const Spacer(),
        Text('边 $bian', style: TextStyle(color: Tokens.text)),
        const SizedBox(width: 14),
        Text('肚 $du', style: TextStyle(color: Tokens.text)),
        const SizedBox(width: 14),
        Text('高 $gao', style: TextStyle(color: Tokens.text)),
      ]));

  /// 走色记录 = 时间轴（日期 + ≤6 图，无备注）
  Widget _timeline(BuildContext context, WidgetRef ref, Walnut w,
      List<Patina> patinas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(children: [
              Text('走色记录（${patinas.length}）',
                  style: TextStyle(
                      fontSize: Tokens.fsHint,
                      color: Tokens.muted,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _addPatina(context, ref, w),
                child: Text('＋ 添加',
                    style: TextStyle(
                        fontSize: Tokens.fsHint,
                        color: Tokens.seal,
                        fontWeight: FontWeight.w700)),
              ),
            ])),
        if (patinas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('暂无走色记录，点右上角「＋走色」添加',
                style:
                    TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
          ),
        for (final p in patinas) _node(context, p),
      ],
    );
  }

  Widget _node(BuildContext context, Patina p) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            const SizedBox(height: 4),
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: Tokens.seal, shape: BoxShape.circle)),
            Expanded(
                child: Container(width: 2, color: Tokens.accentSoft)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.date,
                        style: TextStyle(
                            color: Tokens.text,
                            fontSize: Tokens.fsBody,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _nodeImages(context, p),
                  ]),
            ),
          ),
        ]),
      );

  Widget _nodeImages(BuildContext context, Patina p) => FutureBuilder<List<String>>(
        future: resolvePaths(p.images),
        builder: (c, s) {
          final abs = s.data ?? const <String>[];
          if (abs.isEmpty) {
            return Text('（无图）',
                style:
                    TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint));
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < abs.length; i++)
                GestureDetector(
                  onTap: () => _openAbs(context, abs, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(abs[i]),
                        width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
            ],
          );
        },
      );

  /// 走色图/封面：点开全屏大图（CI 反馈 #2 —— 核心诉求）
  void _openAbs(BuildContext context, List<String> abs, int i) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageViewer(
          files: abs.map((p) => XFile(p)).toList(), initial: i),
    ));
  }

  Future<void> _addPatina(BuildContext context, WidgetRef ref, Walnut w) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddPatinaPage(walnutId: w.id!),
    ));
    if (ok == true) ref.invalidate(patinaByWalnutProvider(id));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Walnut w) async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddWalnutSheet(editWalnut: w),
    ));
    // 刷新列表（返回列表即时生效）+ 按 id 重新取数，根除 B4 编辑后旧值
    refreshCollection(ref);
    ref.invalidate(walnutByIdProvider(id));
    ref.invalidate(patinaByWalnutProvider(id));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Walnut w) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('将删除「${w.name}」及其所有原图，不可恢复。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () async {
                      await DeleteHelper.walnut(w.id!);
                      if (Navigator.canPop(context)) Navigator.pop(context);
                      refreshCollection(ref);
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: Text('删除',
                        style: TextStyle(color: Tokens.badD10))),
              ],
            ));
  }
}
