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
  /// 编辑模式：传入即预填，保存时 update；为空则是新增
  final Item? editItem;
  const AddItemSheet({super.key, this.editItem});
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
  final _buyDateCtl = TextEditingController();
  String _channel = channels.first;
  XFile? _cover; // 本次新选封面
  XFile? _existingCover; // 编辑时已有的封面（解析为文件）
  bool _varietyIsFree = false;
  String? _openCascade; // 当前展开的级联下拉标题（null = 全收起）

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    if (e != null) {
      _type = e.type;
      _category =
          e.category.isNotEmpty ? e.category : itemCategoryVariety.keys.first;
      _variety = e.variety;
      _varietyIsFree = !(_variety.isEmpty ||
          (itemCategoryVariety[_category]?.contains(_variety) ?? false));
      if (_varietyIsFree) _varietyFree.text = _variety;
      _price.text = e.price.toString();
      _size.text = e.sizeMm.toString();
      if (e.type == '手串') _strand.text = e.strandType;
      _weight.text = e.weight.toString();
      _merchant.text = e.merchant;
      _remark.text = e.remark;
      _buyDateCtl.text = e.buyDate;
      _channel = channels.contains(e.channel) ? e.channel : channels.first;
      if (e.coverPath.isNotEmpty) {
        ImageStore.fullPath(e.coverPath).then(
            (p) => mounted ? setState(() => _existingCover = XFile(p)) : null);
      }
    } else {
      _buyDateCtl.text = _today();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _varietyFree,
      _name,
      _price,
      _size,
      _strand,
      _weight,
      _merchant,
      _remark,
      _buyDateCtl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 可用高度 = 屏高 - 键盘；底部再留系统导航栏，确保操作栏不被遮挡/溢出
    final avail = mq.size.height - mq.viewInsets.bottom;
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: avail * 0.92),
      decoration: const BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding:
          EdgeInsets.only(bottom: bottomPad, left: 16, right: 16, top: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _stepper(),
        const SizedBox(height: 10),
        Flexible(
            child: SingleChildScrollView(
                child: _step == 1 ? _step1() : _step2())),
        const SizedBox(height: 10),
        _actions(context),
      ]),
    );
  }

  Widget _stepper() => Row(children: [
        _dot(1, '类型 · 材质'),
        const Expanded(child: Divider(color: Tokens.faint)),
        _dot(2, '尺寸 · 图'),
      ]);
  Widget _dot(int n, String label) => Row(children: [
        NeumorphicBox(
            state: n == _step ? NeuState.raised : NeuState.inset,
            radius: Tokens.rPill,
            width: 26,
            height: 26,
            child: Center(
                child: Text('$n',
                    style: TextStyle(
                        color: n == _step ? Tokens.accent : Tokens.muted)))),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: n == _step ? Tokens.text : Tokens.muted,
                fontSize: Tokens.fsHint)),
      ]);

  Widget _step1() => Column(children: [
        _typeRow(),
        const SizedBox(height: 12),
        _materialRow(),
        const SizedBox(height: 12),
        _varietyRow(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('名称/俗称', _name, '选填')),
          const SizedBox(width: 12),
          Expanded(child: _field('价格(元)', _price, '0', isNum: true))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateField()),
          const SizedBox(width: 12),
          Expanded(child: _channelRow())
        ]),
      ]);

  Widget _typeRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('类型',
              style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: itemTypes
                .map((t) => NeuChip(
                    label: t,
                    active: _type == t,
                    onTap: () => setState(() => _type = t)))
                .toList(),
          ),
        ],
      );

  /// 材质 → 品种：折叠级联下拉（照定稿原型 f-group / f-variety 的 select 级联）
  Widget _materialRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('材质',
              style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
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
        ],
      );

  Widget _varietyRow() {
    if (_varietyIsFree) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('品种（手动输入）',
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        NeuTextField(hint: '如：崖柏', controller: _varietyFree),
      ]);
    }
    final list = itemCategoryVariety[_category] ?? const <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('品种',
          style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
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
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: Tokens.fsBody, color: Tokens.text))),
            Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18, color: Tokens.muted),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((o) => NeuChip(
                        label: o,
                        active: o == label,
                        onTap: () =>
                            setState(() => {_openCascade = null, onPick(o)}),
                      ))
                  .toList(),
            ),
          ),
        ),
    ]);
  }

  Widget _channelRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('入手平台',
              style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: channels
                .map((c) => NeuChip(
                    label: c,
                    active: _channel == c,
                    onTap: () => setState(() => _channel = c)))
                .toList(),
          ),
        ],
      );

  Widget _step2() => SingleChildScrollView(
        child: Column(children: [
          _field('尺寸(mm)', _size, '如 12.0', isNum: true),
          if (_type == '手串') const SizedBox(height: 12),
          if (_type == '手串') _field('串型', _strand, '如：108 颗'),
          const SizedBox(height: 12),
          _field('重量(g)', _weight, '0', isNum: true),
          const SizedBox(height: 12),
          _coverPicker(),
          const SizedBox(height: 12),
          _field('备注', _remark, '选填'),
        ]),
      );

  Widget _field(String label, TextEditingController c, String hint,
          {bool isNum = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        NeuTextField(
            hint: hint,
            controller: c,
            keyboardType: isNum ? TextInputType.number : null),
      ]);

  /// 购买日期：手动文本填入（不点选日历，符合"所有时间手动填入"诉求）
  Widget _dateField() => _field('购买日期', _buyDateCtl, '如 2026-10-04');

  /// 封面选择：展示缩略图；点缩略图看大图（对齐 add_walnut_sheet 的 _thumb/_preview）
  Widget _coverPicker() {
    final cur = _cover ?? _existingCover;
    final has = cur != null;
    return NeumorphicBox(
      radius: Tokens.rCard,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (has) {
              _preview([cur!], 0);
            } else {
              _pickCover();
            }
          },
          child: _thumb(cur, 40),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _pickCover,
            child: Text(
                has ? '封面已选 ✓（点击左侧看大图 / 右侧更换）' : '选封面图',
                style: const TextStyle(color: Tokens.text)),
          ),
        ),
        GestureDetector(
          onTap: _pickCover,
          child: const Icon(Icons.chevron_right, color: Tokens.muted, size: 20),
        ),
      ]),
    );
  }

  Future<void> _pickCover() async {
    final xs = await pickImagesFromSheet(context);
    if (xs.isNotEmpty) setState(() => _cover = xs.first);
  }

  /// 已选图片缩略图；点按可看大图
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
        child: Image.file(File(f.path),
            width: size, height: size, fit: BoxFit.cover),
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

  Widget _actions(BuildContext context) => Row(children: [
        if (_step == 2)
          Expanded(
              child: NeuButton(
                  label: '上一步', onTap: () => setState(() => _step = 1))),
        if (_step == 2) const SizedBox(width: 12),
        Expanded(
            child: NeuButton(
                label: _step == 1 ? '下一步' : '保存',
                onTap: () => _step == 1 ? _next() : _save(context))),
      ]);

  void _next() => setState(() => _step = 2);

  Future<void> _save(BuildContext context) async {
    final e = widget.editItem;
    final variety =
        _varietyIsFree ? _varietyFree.text.trim() : _variety;
    final coverPath = e?.coverPath ?? '';
    final it = Item(
      id: e?.id,
      type: _type,
      code: e?.code ?? '',
      category: _category,
      variety: variety,
      sizeMm: _d(_size),
      strandType: _type == '手串' ? _strand.text.trim() : '',
      weight: _d(_weight),
      buyDate: _buyDateCtl.text,
      channel: _channel,
      merchant: _merchant.text.trim(),
      price: _d(_price),
      coverPath: coverPath,
      remark: _remark.text.trim(),
    );

    int? id;
    if (e != null) {
      await ItemDao.update(it);
      id = e.id;
    } else {
      final count = await ItemDao.countSameDay(_type, _buyDateCtl.text);
      final code = CodeGen.format(_type, _buyDateCtl.text, count);
      id = await ItemDao.insert(
          Item(
            type: it.type,
            code: code,
            category: it.category,
            variety: it.variety,
            sizeMm: it.sizeMm,
            strandType: it.strandType,
            weight: it.weight,
            buyDate: it.buyDate,
            channel: it.channel,
            merchant: it.merchant,
            price: it.price,
            coverPath: '',
            remark: it.remark,
          ));
    }

    // 新选封面则保存并回写
    if (_cover != null && id != null) {
      final rel = await ImageStore.save('item', id, File(_cover!.path));
      await ItemDao.update(Item(
        id: id,
        type: it.type,
        code: it.code,
        category: it.category,
        variety: it.variety,
        sizeMm: it.sizeMm,
        strandType: it.strandType,
        weight: it.weight,
        buyDate: it.buyDate,
        channel: it.channel,
        merchant: it.merchant,
        price: it.price,
        coverPath: rel,
        remark: it.remark,
      ));
    }

    refreshCollection(ref);
    if (mounted) Navigator.pop(context);
  }
}
