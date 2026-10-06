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
import '../../widgets/neu_select.dart';

/// 新增/编辑其他类：全屏页面（CI 反馈 #1 —— 半屏时手机打字看不到填写内容）
class AddItemSheet extends ConsumerStatefulWidget {
  /// 编辑模式：传入即预填，保存时 update；为空则是新增
  final Item? editItem;
  /// 从文玩页点具体分类（手串/吊坠/手把件/摆件）后「＋新增」时预选类型
  final String? initialType;
  const AddItemSheet({super.key, this.editItem, this.initialType});
  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  int _step = 1;
  String _type = itemTypes.first;
  // 品类：手填（删除预设材质/品种级联，用户自行输入，文玩页按此名称统计）
  final _categoryCtl = TextEditingController();
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
  bool _saving = false;

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
      // 升级前录入的记录没有名称，用类型名兜底，避免一进编辑就被必填卡住
      _name.text = e.name.isNotEmpty ? e.name : e.type;
      _categoryCtl.text = e.category;
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
      _type = widget.initialType ?? itemTypes.first;
      _buyDateCtl.text = _today();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _categoryCtl,
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
    // 全屏页面：键盘弹起时 body 整体上移，输入框与操作栏始终可见
    final editing = widget.editItem != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _askExit();
      },
      child: Scaffold(
        backgroundColor: Tokens.bg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Tokens.bg,
          elevation: 0,
          leading: GestureDetector(
              onTap: _askExit,
              child: Icon(Icons.arrow_back, color: Tokens.text)),
          title: Text(editing ? '编辑${_typeLabel()}' : '新增${_typeLabel()}',
              style: TextStyle(
                  color: Tokens.text,
                  fontSize: Tokens.fsEmph,
                  fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _stepper()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _step == 1 ? _step1() : _step2(),
              ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _actions(context)),
          ]),
        ),
      ),
    );
  }

  String _typeLabel() => _type;

  /// 必填校验（CI 反馈 #8）：名称 / 购买渠道 / 购买价格 / 购买日期
  List<String> _missing() {
    final m = <String>[];
    if (_name.text.trim().isEmpty) m.add('名称');
    if (_channel.trim().isEmpty) m.add('购买渠道');
    if (_price.text.trim().isEmpty) m.add('购买价格');
    if (_buyDateCtl.text.trim().isEmpty) m.add('购买日期');
    return m;
  }

  /// 右滑返回 / 点返回键：三选弹窗（保存并退出 / 不保存退出 / 继续编辑）
  Future<void> _askExit() async {
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('是否保存'),
        content: const Text('这条记录还没保存，要保存后退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, 'save'),
              child: const Text('保存并退出')),
          TextButton(
              onPressed: () => Navigator.pop(d, 'drop'),
              child: const Text('不保存退出')),
          TextButton(
              onPressed: () => Navigator.pop(d, 'stay'),
              child: const Text('继续编辑')),
        ],
      ),
    );
    if (r == null || r == 'stay') return;
    if (r == 'save') {
      final miss = _missing();
      if (miss.isNotEmpty) {
        _toast('请填写：${miss.join('、')}');
        return;
      }
      if (!mounted) return;
      await _save(context);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _stepper() => Row(children: [
        _dot(1, '类型 · 品类'),
        Expanded(child: Divider(color: Tokens.faint)),
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
        _categoryField(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('名称', _name, '必填')),
          const SizedBox(width: 12),
          Expanded(child: _field('价格(元)', _price, '必填', isNum: true))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateField()),
          const SizedBox(width: 12),
          Expanded(child: _channelRow())
        ]),
        const SizedBox(height: 12),
        // 核桃页有商家、其他类一直缺，商家字段永远存不进去 → 补齐
        _field('商家', _merchant, '选填'),
      ]);

  Widget _typeRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('类型',
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

  /// 品类：手填（删除预设材质/品种级联，用户自行输入，文玩页按此名称统计）
  Widget _categoryField() =>
      _field('品类（手填）', _categoryCtl, '如：星月菩提 / 南红 / 猛犸');

  /// 入手平台：下拉菜单（CI 反馈 #6 —— 原型是 select，之前被做成按钮，改回下拉）
  Widget _channelRow() => NeuSelect(
        label: '入手平台',
        current: _channel,
        options: channels,
        onPick: (v) => setState(() => _channel = v),
      );

  Widget _step2() => Column(children: [
        _field('尺寸(mm)', _size, '如 12.0', isNum: true),
        if (_type == '手串') const SizedBox(height: 12),
        if (_type == '手串') _field('串型', _strand, '如：108 颗'),
        const SizedBox(height: 12),
        _field('重量(g)', _weight, '0', isNum: true),
        const SizedBox(height: 12),
        _coverPicker(),
        const SizedBox(height: 12),
        _field('备注', _remark, '选填'),
      ]);

  Widget _field(String label, TextEditingController c, String hint,
          {bool isNum = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
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
              _preview([cur], 0);
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
                style: TextStyle(color: Tokens.text)),
          ),
        ),
        GestureDetector(
          onTap: _pickCover,
          child: Icon(Icons.chevron_right, color: Tokens.muted, size: 20),
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
        child: Icon(Icons.image_outlined, color: Tokens.faint, size: 18),
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

  void _next() {
    final miss = _missing();
    if (miss.isNotEmpty) {
      _toast('请填写：${miss.join('、')}');
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _save(BuildContext context) async {
    // 防重复提交：连点「保存」会插入两条一模一样的记录
    if (_saving) return;
    final miss = _missing();
    if (miss.isNotEmpty) {
      _toast('请填写：${miss.join('、')}');
      return;
    }
    setState(() => _saving = true);
    try {
      await _doSave(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _doSave(BuildContext context) async {
    final e = widget.editItem;
    final coverPath = e?.coverPath ?? '';
    final it = Item(
      id: e?.id,
      type: _type,
      name: _name.text.trim(), // 之前漏了这一行：名称只校验不入库
      code: e?.code ?? '',
      category: _categoryCtl.text.trim(),
      variety: '',
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
    // code 必须提到分支外：新增时 it.code 是 ''，若后面回写封面仍用 it.code
    // 会把刚生成的编号覆盖成空串。
    late final String code;
    if (e != null) {
      await ItemDao.update(it);
      id = e.id;
      code = e.code;
    } else {
      final seq = await ItemDao.maxSeqSameDay(_type, _buyDateCtl.text);
      code = CodeGen.format(_type, _buyDateCtl.text, seq);
      id = await ItemDao.insert(Item(
        type: it.type,
        name: it.name,
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
      // 换了封面就清理旧封面文件
      if (e != null && e.coverPath.isNotEmpty && e.coverPath != rel) {
        await ImageStore.deleteFile(e.coverPath);
      }
      await ItemDao.update(Item(
        id: id,
        type: it.type,
        name: it.name,
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
        coverPath: rel,
        remark: it.remark,
      ));
    }

    refreshCollection(ref, itemId: id);
    if (context.mounted) Navigator.pop(context);
  }
}
