import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/format.dart';
import '../../logic/delete_helper.dart';
import '../../data/models/item.dart';
import '../../widgets/cover_thumb.dart';
import '../../widgets/cover_carousel.dart';
import '../../widgets/image_viewer.dart';

/// 其他类（手串/吊坠/手把件/摆件）详情页。
/// 评审意见 P0 第一层：只收 id，经 itemByIdProvider 按 id 取数，与核桃详情页统一。
class ItemDetailPage extends ConsumerWidget {
  final int id;
  const ItemDetailPage(this.id, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = ref.watch(itemByIdProvider(id));
    return it.when(
      loading: () => _frame(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _frame(Center(child: Text('加载失败: $e'))),
      data: (item) {
        if (item == null) {
          return _frame(const Center(child: Text('未找到该藏品')));
        }
        return _scaffold(context, ref, item);
      },
    );
  }

  Widget _frame(Widget child) =>
      Scaffold(backgroundColor: Tokens.bg, body: SafeArea(child: child));

  Widget _scaffold(BuildContext context, WidgetRef ref, Item it) => Scaffold(
        backgroundColor: Tokens.bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
            leading: GestureDetector(onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, color: Tokens.text)),
            title: Text(it.type, style: TextStyle(color: Tokens.text))),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child:
              Row(children: [
                _cover(context, it),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.name.isNotEmpty ? it.name : it.type, style: TextStyle(fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold, color: Tokens.text)),
                  const SizedBox(height: 6),
                  if (it.name.isNotEmpty)
                    Text(it.type, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
                  if (it.name.isNotEmpty) const SizedBox(height: 6),
                  Text('${it.category} · ${it.variety}', style: TextStyle(color: Tokens.muted)),
                  const SizedBox(height: 8),
                  Text(it.code, style: TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
                  const SizedBox(height: 6),
                  Text(formatPrice(it.price), style: TextStyle(fontSize: Tokens.fsEmph, color: Tokens.accent, fontWeight: FontWeight.w700)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            _section('规格', [
              _kv('尺寸', formatSize(it.sizeMm)),
              if (it.type == '手串') _kv('串型', it.strandType.isEmpty ? '—' : it.strandType),
              _kv('重量', formatWeight(it.weight)),
            ]),
            _section('入手信息', [
              _kv('购买日期', it.buyDate),
              _kv('入手平台', it.channel.isEmpty ? '—' : it.channel),
              _kv('商家', it.merchant.isEmpty ? '—' : it.merchant),
            ]),
            if (it.remark.isNotEmpty) _section('备注', [_kv('', it.remark)]),
            const SizedBox(height: 24),
            GestureDetector(onTap: () => _confirmDelete(context, ref, it), child:
              NeumorphicBox(state: NeuState.raised, radius: Tokens.rBtn, padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: Text('删除这件', style: TextStyle(color: Tokens.badD10, fontWeight: FontWeight.w700))))),
          ]),
        ),
      );

  /// 封面：点开全屏大图（CI 反馈 #2 —— 之前点了没反应）
  Widget _cover(BuildContext context, Item it) => FutureBuilder<List<String>>(
        future: resolvePaths([it.coverPath]),
        builder: (c, s) {
          final abs = s.data ?? const <String>[];
          if (abs.isEmpty) return CoverThumb(rel: it.coverPath, size: 84);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ImageViewer(
                  files: abs.map((p) => XFile(p)).toList(), initial: 0),
            )),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(abs[0]),
                  width: 84, height: 84, fit: BoxFit.cover),
            ),
          );
        },
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title, style: TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted, fontWeight: FontWeight.w700))),
          NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child: Column(children: children)),
          const SizedBox(height: 16),
        ],
      );

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        if (k.isNotEmpty) Text(k, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsBody)),
        if (k.isNotEmpty) const Spacer(),
        Expanded(child: Text(v, style: TextStyle(color: Tokens.text, fontSize: Tokens.fsBody), textAlign: k.isEmpty ? TextAlign.left : TextAlign.right)),
      ]));

  void _confirmDelete(BuildContext context, WidgetRef ref, Item it) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('将删除「${it.type}」及其所有原图，不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(                    onPressed: () async {
                      await DeleteHelper.item(it.id!);
                      if (Navigator.canPop(context)) Navigator.pop(context);
          refreshCollection(ref);
          if (Navigator.canPop(context)) Navigator.pop(context);
        }, child: Text('删除', style: TextStyle(color: Tokens.badD10))),
      ],
    ));
  }
}
