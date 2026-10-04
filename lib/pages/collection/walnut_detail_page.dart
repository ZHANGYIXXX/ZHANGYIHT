import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/format.dart';
import '../../data/models/walnut.dart';
import '../../data/models/patina.dart';
import '../../data/daos/walnut_dao.dart';
import '../../data/daos/patina_dao.dart';
import '../../data/image_store.dart';
import '../../widgets/cover_thumb.dart';

class WalnutDetailPage extends ConsumerWidget {
  final Walnut w;
  const WalnutDetailPage(this.w, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Patina>>(
      future: PatinaDao.byWalnut(w.id!),
      builder: (c, snap) {
        final patinas = snap.data ?? const <Patina>[];
        return Scaffold(
          backgroundColor: Tokens.bg,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
              leading: GestureDetector(onTap: () => Navigator.pop(c),
                  child: const Icon(Icons.arrow_back, color: Tokens.text)),
              title: Text(w.name, style: const TextStyle(color: Tokens.text))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child:
                  Row(children: [
                    CoverThumb(rel: w.coverPath, size: 84),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.name, style: const TextStyle(fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold, color: Tokens.text)),
                      const SizedBox(height: 6),
                      Text('${w.category} · ${w.variety}', style: const TextStyle(color: Tokens.muted)),
                      const SizedBox(height: 8),
                      Text(w.code, style: const TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
                      const SizedBox(height: 6),
                      Text(formatPrice(w.price), style: const TextStyle(fontSize: Tokens.fsEmph, color: Tokens.accent, fontWeight: FontWeight.w700)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                _tagsRow(),
                const SizedBox(height: 16),
                _section('尺寸（六面 / mm）', [
                  _sizeRow('左', w.lBian, w.lDu, w.lGao),
                  _sizeRow('右', w.rBian, w.rDu, w.rGao),
                  _kv('重量', formatWeight(w.weight)),
                ]),
                _section('入手信息', [
                  _kv('购买日期', w.buyDate),
                  _kv('入手平台', w.channel.isEmpty ? '—' : w.channel),
                  _kv('商家', w.merchant.isEmpty ? '—' : w.merchant),
                ]),
                if (w.remark.isNotEmpty) _section('备注', [_kv('', w.remark)]),
                const SizedBox(height: 8),
                _patinaBlock(patinas),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _confirmDelete(context, ref),
                  child: NeumorphicBox(state: NeuState.raised, radius: Tokens.rBtn,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Center(child: Text('删除这件', style: TextStyle(color: Tokens.badD10, fontWeight: FontWeight.w700)))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tagsRow() => Wrap(spacing: 8, runSpacing: 8,
      children: patinaTags(full: w.full, repaired: w.repaired, yellow: w.yellow)
          .map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Tokens.accentSoft, borderRadius: BorderRadius.circular(10)),
              child: Text(t, style: const TextStyle(color: Tokens.accent, fontSize: Tokens.fsHint)))).toList());

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

  Widget _sizeRow(String side, double bian, double du, double gao) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(side, style: const TextStyle(color: Tokens.muted)),
        const Spacer(),
        Text('边 $bian', style: const TextStyle(color: Tokens.text)),
        const SizedBox(width: 14),
        Text('肚 $du', style: const TextStyle(color: Tokens.text)),
        const SizedBox(width: 14),
        Text('高 $gao', style: const TextStyle(color: Tokens.text)),
      ]));

  Widget _patinaBlock(List<Patina> patinas) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('走色记录（${patinas.length}）', style: const TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted, fontWeight: FontWeight.w700))),
          if (patinas.isEmpty) const Text('  暂无，可在「新增」第二步添加', style: TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
          for (final p in patinas) NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(14), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.date, style: const TextStyle(color: Tokens.accent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: p.images.map((rel) => _patinaImg(rel)).toList()),
            ])),
        ],
      );

  Widget _patinaImg(String rel) => FutureBuilder<String>(future: ImageStore.fullPath(rel), builder: (c, s) =>
      s.hasData ? ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Image.file(File(s.data!), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_,__,___)=>_ph()))
          : _ph());

  Widget _ph() => Container(width: 72, height: 72, decoration: BoxDecoration(color: Tokens.bg, borderRadius: BorderRadius.circular(10), boxShadow: Tokens.inSm),
      child: const Icon(Icons.image_outlined, color: Tokens.faint, size: 20));

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('将删除「${w.name}」及其所有原图，不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () async {
          await ImageStore.deleteDir('walnut', w.id!);
          await WalnutDao.delete(w.id!);
          if (Navigator.canPop(context)) Navigator.pop(context); // close dialog
          refreshCollection(ref);
          if (Navigator.canPop(context)) Navigator.pop(context); // back to list
        }, child: const Text('删除', style: TextStyle(color: Tokens.badD10))),
      ],
    ));
  }
}
