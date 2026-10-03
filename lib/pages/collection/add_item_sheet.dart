import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/codegen.dart';
import '../../data/models/enums.dart';
import '../../data/models/item.dart';
import '../../data/daos/item_dao.dart';
import '../../data/image_store.dart';
import '../../widgets/image_pick_sheet.dart';
import '../../widgets/image_viewer.dart';

class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key});
  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  int _step = 1;
  String _type = itemTypes.first;
  String _category = itemCategoryVariety.keys.first;
  String _variety = itemCategoryVariety.values.first.first;
  final _varietyFree = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _size = TextEditingController();
  final _strand = TextEditingController();
  final _weight = TextEditingController();
  final _merchant = TextEditingController();
  final _remark = TextEditingController();
  String _buyDate = _today();
  String _channel = channels.first;
  XFile? _cover;
  bool _varietyIsFree = false;
  String? _openCascade; // 当前展开的级联下拉标题（null = 全收起）

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final c in [_varietyFree, _name, _price, _size, _strand, _weight, _merchant, _remark]) c.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    // 只给最大高度上限 + 弹性滚动：竖屏自然撑开，横屏/折叠态压缩转滚动，
    // 底部操作栏固定可见，不会被内容顶出屏幕
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: Tokens.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _stepper(),
        const SizedBox(height: 10),
        Flexible(child: SingleChildScrollView(child: _step == 1 ? _step1() : _step2())),
        const SizedBox(height: 10),
        _actions(context),
      ]),
    );
  }

  Widget _stepper() => Row(children: [
        _dot(1, '类型 · 材质'), const Expanded(child: Divider(color: Tokens.faint)), _dot(2, '尺寸 · 图'),
      ]);
  Widget _dot(int n, String label) => Row(children: [
        NeumorphicBox(state: n == _step ? NeuState.raised : NeuState.inset, radius: Tokens.rPill, width: 26, height: 26,
            child: Center(child: Text('$n', style: TextStyle(color: n == _step ? Tokens.accent : Tokens.muted)))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: n == _step ? Tokens.text : Tokens.muted, fontSize: Tokens.fsHint)),
      ]);

  Widget _step1() => Column(children: [
        _typeRow(),
        const SizedBox(height: 12),
        _materialRow(),
        const SizedBox(height: 12),
        _varietyRow(),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _field('名称/俗称', _name, '选填')), const SizedBox(width: 12), Expanded(child: _field('价格(元)', _price, '0', isNum: true))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _dateField()), const SizedBox(width: 12), Expanded(child: _channelRow())]),
      ]);

  Widget _typeRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('类型', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: itemTypes.map((t) => NeuChip(label: t, active: _type == t,
        onTap: () => setState(() => _type = t))).toList()),
  ]);

  /// 材质 → 品种：折叠级联下拉（照定稿原型 f-group / f-variety 的 select 级联）
  Widget _materialRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('材质', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
    const SizedBox(height: 8),
    _cascade(
      label: _category,
      options: itemCategoryVariety.keys.toList(),
      onPick: (m) => setState(() {
        _category = m;
        final list = itemCategoryVariety[m]!;
        _varietyIsFree = list.isEmpty;
        _variety = list.isEmpty ? '' : list.first;
      }),
    ),
  ]);

  Widget _varietyRow() {
    if (_varietyIsFree) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('品种（手动输入）', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        NeuTextField(hint: '如：崖柏', controller: _varietyFree),
      ]);
    }
    final list = itemCategoryVariety[_category] ?? const <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('品种', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
      const SizedBox(height: 8),
      _cascade(
        label: _variety.isEmpty ? '不选' : _variety,
        options: ['不选', ...list],
        onPick: (v) => setState(() => _variety = v == '不选' ? '' : v),
      ),
    ]);
  }

  /// 折叠级联下拉：点标题展开选项，再点已选项取消
  Widget _cascade({
    required String label,
    required List<String> options,
    required ValueChanged<String> onPick,
  }) {
    final open = _openCascade == label;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _openCascade = open ? null : label),
        child: NeumorphicBox(
          state: open ? NeuState.inset : NeuState.raised,
          radius: Tokens.rInput,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: Tokens.fsBody, color: Tokens.text))),
            Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18, color: Tokens.muted),
          ]),
        ),
      ),
      if (open)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: NeumorphicBox(
            state: NeuState.inset,
            radius: Tokens.rInput,
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 8, runSpacing: 8, children: options.map((o) => NeuChip(
              label: o,
              active: o == label,
              onTap: () => setState(() { _openCascade = null; onPick(o); }),
            )).toList()),
          ),
        ),
    ]);
  }

  Widget _channelRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('入手平台', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: channels.map((c) => NeuChip(label: c, active: _channel == c,
        onTap: () => setState(() => _channel = c))).toList()),
  ]);

  Widget _step2() => SingleChildScrollView(child: Column(children: [
    _field('尺寸(mm)', _size, '如 12.0', isNum: true),
    if (_type == '手串') const SizedBox(height: 12),
    if (_type == '手串') _field('串型', _strand, '如：108 颗'),
    const SizedBox(height: 12),
    _field('重量(g)', _weight, '0', isNum: true),
    const SizedBox(height: 12),
    _coverPicker(),
    const SizedBox(height: 12),
    _field('备注', _remark, '选填'),
  ]));

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

  Widget _coverPicker() => GestureDetector(onTap: () async {
    final xs = await pickImagesFromSheet(context);
    if (xs.isNotEmpty) setState(() => _cover = xs.first);
  }, child: NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(14), child: Row(children: [
        const Icon(Icons.photo, color: Tokens.accent), const SizedBox(width: 10),
        Text(_cover == null ? '选封面图' : '封面已选 ✓', style: const TextStyle(color: Tokens.text)),
      ])));

  Widget _actions(BuildContext context) => Row(children: [
    if (_step == 2) Expanded(child: NeuButton(label: '上一步', onTap: () => setState(() => _step = 1))),
    if (_step == 2) const SizedBox(width: 12),
    Expanded(child: NeuButton(label: _step == 1 ? '下一步' : '保存', onTap: () => _step == 1 ? _next() : _save(context))),
  ]);

  void _next() => setState(() => _step = 2);

  Future<void> _save(BuildContext context) async {
    final variety = _varietyIsFree ? _varietyFree.text.trim() : _variety;
    final count = await ItemDao.countSameDay(_type, _buyDate);
    final code = CodeGen.format(_type, _buyDate, count);
    final it = Item(type: _type, code: code, category: _category, variety: variety,
        sizeMm: _d(_size), strandType: _type == '手串' ? _strand.text.trim() : '', weight: _d(_weight),
        buyDate: _buyDate, channel: _channel, merchant: _merchant.text.trim(), price: _d(_price),
        coverPath: '', remark: _remark.text.trim());
    final id = await ItemDao.insert(it);
    if (_cover != null) {
      final rel = await ImageStore.save('item', id, File(_cover!.path));
      await ItemDao.update(Item(id: id, type: it.type, code: it.code, category: it.category, variety: it.variety,
          sizeMm: it.sizeMm, strandType: it.strandType, weight: it.weight, buyDate: it.buyDate,
          channel: it.channel, merchant: it.merchant, price: it.price, coverPath: rel, remark: it.remark));
    }
    refreshCollection(ref);
    if (mounted) Navigator.pop(context);
  }
}
