import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/format.dart';
import '../../data/models/item.dart';
import '../../data/daos/item_dao.dart';
import '../../data/image_store.dart';
import '../../widgets/cover_thumb.dart';

class ItemDetailPage extends ConsumerWidget {
  final Item it;
  const ItemDetailPage(this.it, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: Tokens.bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
            leading: GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Tokens.text)),
            title: Text(it.type, style: const TextStyle(color: Tokens.text))),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child:
              Row(children: [
                CoverThumb(rel: it.coverPath, size: 84),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.type, style: const TextStyle(fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold, color: Tokens.text)),
                  const SizedBox(height: 6),
                  Text('${it.category} · ${it.variety}', style: const TextStyle(color: Tokens.muted)),
                  const SizedBox(height: 8),
                  Text(it.code, style: const TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
                  const SizedBox(height: 6),
                  Text(formatPrice(it.price), style: const TextStyle(fontSize: Tokens.fsEmph, color: Tokens.accent, fontWeight: FontWeight.w700)),
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
            GestureDetector(onTap: () => _confirmDelete(context, ref), child:
              NeumorphicBox(state: NeuState.raised, radius: Tokens.rBtn, padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(child: Text('删除这件', style: TextStyle(color: Tokens.badD10, fontWeight: FontWeight.w700))))),
          ]),
        ),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title, style: const TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted, fontWeight: FontWeight.w700))),
          NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child: Column(children: children)),
          const SizedBox(height: 16),
        ],
      );

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        if (k.isNotEmpty) Text(k, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsBody)),
        if (k.isNotEmpty) const Spacer(),
        Expanded(child: Text(v, style: const TextStyle(color: Tokens.text, fontSize: Tokens.fsBody), textAlign: k.isEmpty ? TextAlign.left : TextAlign.right)),
      ]));

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('将删除「${it.type}」及其所有原图，不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () async {
          await ImageStore.deleteDir('item', it.id!);
          await ItemDao.delete(it.id!);
          if (Navigator.canPop(context)) Navigator.pop(context);
          refreshCollection(ref);
          if (Navigator.canPop(context)) Navigator.pop(context);
        }, child: const Text('删除', style: TextStyle(color: Tokens.badD10))),
      ],
    ));
  }
}
