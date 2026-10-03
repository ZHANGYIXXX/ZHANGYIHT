import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/codegen.dart';
import '../../logic/validate.dart';
import '../../data/models/enums.dart';
import '../../data/models/walnut.dart';
import '../../data/models/patina.dart';
import '../../data/daos/walnut_dao.dart';
import '../../data/daos/patina_dao.dart';
import '../../data/image_store.dart';
import '../../widgets/image_pick_sheet.dart';
import '../../widgets/image_viewer.dart';

class AddWalnutSheet extends ConsumerStatefulWidget {
  const AddWalnutSheet({super.key});
  @override
  ConsumerState<AddWalnutSheet> createState() => _AddWalnutSheetState();
}

class _AddWalnutSheetState extends ConsumerState<AddWalnutSheet> {
  int _step = 1;
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _merchant = TextEditingController();
  final _remark = TextEditingController();
  String _buyDate = _today();
  // 大品类/品种：默认不选，需用户展开后主动选择（避免一进来铺开二十多个品种）
  String? _category;
  String? _variety;
  bool _cascadeOpen = false;
  String _channel = channels.first;
  final _lBian = TextEditingController();
  final _lDu = TextEditingController();
  final _lGao = TextEditingController();
  final _rBian = TextEditingController();
  final _rDu = TextEditingController();
  final _rGao = TextEditingController();
  final _weight = TextEditingController();
  bool _full = false, _repaired = false, _yellow = false;
  XFile? _cover;
  final List<XFile> _patina = [];

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _merchant, _remark, _lBian, _lDu, _lGao, _rBian, _rDu, _rGao, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    // 只给「最大高度」上限、不写死高度：
    // 竖屏时内容自然撑开，横屏/折叠态时自动压缩并转为可滚动，
    // 底部操作栏始终固定可见（不会被内容顶出屏幕）
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
          color: Tokens.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _stepper(),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: _step == 1 ? _step1() : _step2(),
          ),
        ),
        const SizedBox(height: 10),
        _actions(context),
      ]),
    );
  }

  Widget _stepper() => Row(children: [
        _stepDot(1, '基本信息'),
        const Expanded(child: Divider(color: Tokens.faint)),
        _stepDot(2, '尺寸 · 品相 · 图'),
      ]);

  Widget _stepDot(int n, String label) => Row(children: [
        NeumorphicBox(state: n == _step ? NeuState.raised : NeuState.inset, radius: Tokens.rPill,
            width: 26, height: 26, child: Center(child: Text('$n', style: TextStyle(color: n == _step ? Tokens.accent : Tokens.muted)))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: n == _step ? Tokens.text : Tokens.muted, fontSize: Tokens.fsHint)),
      ]);

  Widget _step1() => Column(children: [
        _field('名称', _name, '如：四座楼矮桩'),
        const SizedBox(height: 12),
        _cascade(),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _field('价格(元)', _price, '0', isNum: true)), const SizedBox(width: 12), Expanded(child: _dateField())]),
        const SizedBox(height: 12),
        _channelRow(),
        const SizedBox(height: 12),
        _field('商家', _merchant, '选填'),
      ]);

  Widget _cascade() {
    final sub = _category == null ? const <String>[] : walnutVarieties[_category]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 点标题展开/收起，默认收起，避免一进来就铺开二十多个品种
      GestureDetector(
        onTap: () => setState(() => _cascadeOpen = !_cascadeOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Text('大品类 → 品种',
                style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
            const Spacer(),
            Icon(_cascadeOpen ? Icons.expand_less : Icons.expand_more,
                color: Tokens.muted, size: 18),
          ]),
        ),
      ),
      if (_cascadeOpen) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: walnutCategories.map((c) {
          final active = _category == c;
          return NeuChip(label: c, active: active, onTap: () {
            setState(() {
              if (active) {
                // 再点一次取消选择
                _category = null;
                _variety = null;
              } else {
                _category = c;
                _variety = null;
              }
            });
          });
        }).toList()),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('选择品种',
              style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: sub.map((v) => NeuChip(
                  label: v,
                  active: _variety == v,
                  onTap: () => setState(() {
                    _variety = _variety == v ? null : v;
                  })))
              .toList()),
        ],
      ],
    ]);
  }

  Widget _channelRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('入手平台', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: channels.map((c) => NeuChip(label: c, active: _channel == c,
            onTap: () => setState(() => _channel = c))).toList()),
      ]);

  Widget _step2() => SingleChildScrollView(child: Column(children: [
        _sizeGrid(),
        const SizedBox(height: 12),
        _field('重量(g)', _weight, '0', isNum: true),
        const SizedBox(height: 12),
        _patinaSwitchRow(),
        const SizedBox(height: 12),
        _coverPicker(),
        const SizedBox(height: 12),
        _patinaPicker(),
        const SizedBox(height: 12),
        _field('备注', _remark, '选填'),
      ]));

  Widget _sizeGrid() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('六面尺寸(mm)', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: _field('左·边', _lBian, '0', isNum: true)), const SizedBox(width: 8), Expanded(child: _field('左·肚', _lDu, '0', isNum: true)), const SizedBox(width: 8), Expanded(child: _field('左·高', _lGao, '0', isNum: true))]),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: _field('右·边', _rBian, '0', isNum: true)), const SizedBox(width: 8), Expanded(child: _field('右·肚', _rDu, '0', isNum: true)), const SizedBox(width: 8), Expanded(child: _field('右·高', _rGao, '0', isNum: true))]),
  ]);

  Widget _patinaSwitchRow() => NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(14), child: Column(children: [
    _switch('全品', _full, (v) => setState(() { _full = v; final c = Validate.coerce(_full, _repaired); _full = c.full; _repaired = c.repaired; })),
    _switch('有修', _repaired, (v) => setState(() { _repaired = v; final c = Validate.coerce(_full, _repaired); _full = c.full; _repaired = c.repaired; })),
    _switch('有黄', _yellow, (v) => setState(() => _yellow = v)),
  ]));

  Widget _switch(String label, bool v, ValueChanged<bool> on) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Text(label, style: const TextStyle(color: Tokens.text)), const Spacer(), NeuSwitch(value: v, onChanged: on)]));

  Widget _coverPicker() => GestureDetector(onTap: () async {
        final xs = await pickImagesFromSheet(context);
        if (xs.isNotEmpty) setState(() => _cover = xs.first);
      }, child: NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(14), child: Row(children: [
        _thumb(_cover, 40),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_cover == null ? '选封面图' : '封面已选 ✓（点击可更换）',
              style: const TextStyle(color: Tokens.text)),
        ),
        const Icon(Icons.chevron_right, color: Tokens.muted, size: 20),
      ])));

  Widget _patinaPicker() => GestureDetector(onTap: () async {
        final xs = await pickImagesFromSheet(context, multiple: true);
        if (xs.isNotEmpty) setState(() => _patina.addAll(xs));
      }, child: NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(14), child: Row(children: [
        const Icon(Icons.collections, color: Tokens.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_patina.isEmpty ? '添加走色记录图（可多张）' : '已选 ${_patina.length} 张走色图',
              style: const TextStyle(color: Tokens.text)),
        ),
        const Icon(Icons.chevron_right, color: Tokens.muted, size: 20),
      ])));

  /// 已选图片缩略图；点按图片本身可看大图
  Widget _thumb(XFile? f, double size) {
    if (f == null) {
      return NeumorphicBox(
        state: NeuState.inset,
        radius: size / 3,
        width: size,
        height: size,
        child: const Icon(Icons.image_outlined, color: Tokens.faint, size: 18),
      );
    }
    return GestureDetector(
      onTap: () => _preview([f], 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 3),
        child: Image.file(File(f.path), width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }

  /// 全屏大图预览，支持左右滑动切换
  void _preview(List<XFile> files, int index) {
    if (files.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ImageViewer(files: files, initial: index),
    );
  }

  Widget _field(String label, TextEditingController c, String hint, {bool isNum = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        NeuTextField(hint: hint, controller: c, keyboardType: isNum ? TextInputType.number : null),
      ]);

  Widget _dateField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('购买日期', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        GestureDetector(onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setState(() => _buyDate = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        }, child: NeumorphicBox(radius: Tokens.rInput, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(_buyDate, style: const TextStyle(color: Tokens.text)))),
      ]);

  Widget _actions(BuildContext context) => Row(children: [
        if (_step == 2) Expanded(child: NeuButton(label: '上一步', onTap: () => setState(() => _step = 1))),
        if (_step == 2) const SizedBox(width: 12),
        Expanded(child: NeuButton(label: _step == 1 ? '下一步' : '保存', onTap: () => _step == 1 ? _next() : _save(context))),
      ]);

  void _next() {
    if (_name.text.trim().isEmpty) { _toast('请填写名称'); return; }
    setState(() => _step = 2);
  }

  Future<void> _save(BuildContext context) async {
    if (_name.text.trim().isEmpty) { _toast('请填写名称'); return; }
    final count = await WalnutDao.countSameDay(_buyDate);
    final code = CodeGen.format('核桃', _buyDate, count);
    var w = Walnut(code: code, name: _name.text.trim(), category: _category ?? '', variety: _variety ?? '',
        price: _d(_price), lBian: _d(_lBian), lDu: _d(_lDu), lGao: _d(_lGao),
        rBian: _d(_rBian), rDu: _d(_rDu), rGao: _d(_rGao), weight: _d(_weight),
        buyDate: _buyDate, channel: _channel, merchant: _merchant.text.trim(),
        full: _full, repaired: _repaired, yellow: _yellow, remark: _remark.text.trim());
    final id = await WalnutDao.insert(w);
    if (_cover != null) {
      final rel = await ImageStore.save('walnut', id, File(_cover!.path));
      await WalnutDao.update(Walnut(id: id, code: code, name: w.name, category: w.category, variety: w.variety,
          price: w.price, lBian: w.lBian, lDu: w.lDu, lGao: w.lGao, rBian: w.rBian, rDu: w.rDu, rGao: w.rGao,
          weight: w.weight, buyDate: w.buyDate, channel: w.channel, merchant: w.merchant,
          full: w.full, repaired: w.repaired, yellow: w.yellow, remark: w.remark, coverPath: rel));
    }
    if (_patina.isNotEmpty) {
      final rels = <String>[];
      for (final f in _patina) rels.add(await ImageStore.save('patina', id, File(f.path)));
      await PatinaDao.insert(Patina(walnutId: id, date: _buyDate, images: rels));
    }
    refreshCollection(ref);
    if (mounted) Navigator.pop(context);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
