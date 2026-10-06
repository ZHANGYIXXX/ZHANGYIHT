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
import '../../widgets/neu_select.dart';

/// 新增/编辑核桃：全屏页面（CI 反馈 #1 —— 半屏时手机打字看不到填写内容）
class AddWalnutSheet extends ConsumerStatefulWidget {
  /// 编辑模式：传入即预填，保存时 update；为空则是新增
  final Walnut? editWalnut;
  const AddWalnutSheet({super.key, this.editWalnut});
  @override
  ConsumerState<AddWalnutSheet> createState() => _AddWalnutSheetState();
}

class _AddWalnutSheetState extends ConsumerState<AddWalnutSheet> {
  int _step = 1;
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _merchant = TextEditingController();
  final _remark = TextEditingController();
  final _buyDateCtl = TextEditingController(text: _today());
  // 走色记录日期：与购买日期独立，照片拍摄时间可单独填写（满足"上传照片时间可选"）
  final _patinaDateCtl = TextEditingController(text: _today());
  // 品类：手填（删除预设大类/品种，全部由用户自行输入，文玩页按此名称统计）
  final _categoryCtl = TextEditingController();
  String _channel = channels.first;
  final _lBian = TextEditingController();
  final _lDu = TextEditingController();
  final _lGao = TextEditingController();
  final _rBian = TextEditingController();
  final _rDu = TextEditingController();
  final _rGao = TextEditingController();
  final _weight = TextEditingController();
  bool _full = false, _repaired = false, _yellow = false;
  bool _saving = false;
  XFile? _cover; // 本次新选封面
  XFile? _existingCover; // 编辑时已有的封面（解析为文件）
  final List<XFile> _patina = [];

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editWalnut;
    if (e != null) {
      _name.text = e.name;
      _categoryCtl.text = e.category;
      _price.text = e.price.toString();
      _lBian.text = e.lBian.toString();
      _lDu.text = e.lDu.toString();
      _lGao.text = e.lGao.toString();
      _rBian.text = e.rBian.toString();
      _rDu.text = e.rDu.toString();
      _rGao.text = e.rGao.toString();
      _weight.text = e.weight.toString();
      _buyDateCtl.text = e.buyDate;
      _channel = channels.contains(e.channel) ? e.channel : channels.first;
      _full = e.full;
      _repaired = e.repaired;
      _yellow = e.yellow;
      _merchant.text = e.merchant;
      _remark.text = e.remark;
      if (e.coverPath.isNotEmpty) {
        ImageStore.fullPath(e.coverPath)
            .then((p) => mounted ? setState(() => _existingCover = XFile(p)) : null);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _merchant,
      _remark,
      _lBian,
      _lDu,
      _lGao,
      _rBian,
      _rDu,
      _rGao,
      _weight,
      _buyDateCtl,
      _patinaDateCtl,
      _categoryCtl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    // 全屏页面：键盘弹起时 body 整体上移（resizeToAvoidBottomInset），
    // 输入框与「下一步/保存」操作栏始终可见。
    final editing = widget.editWalnut != null;
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
          title: Text(editing ? '编辑核桃' : '新增核桃',
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
        return; // 仍不填 → 留在页面，再右滑会再次提示
      }
      await _save(context);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _stepper() => Row(children: [
        _stepDot(1, '基本信息'),
        Expanded(child: Divider(color: Tokens.faint)),
        _stepDot(2, '尺寸 · 品相 · 图'),
      ]);

  Widget _stepDot(int n, String label) => Row(children: [
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
        _field('名称', _name, '如：四座楼矮桩'),
        const SizedBox(height: 12),
        _categoryField(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('价格(元)', _price, '0', isNum: true)),
          const SizedBox(width: 12),
          Expanded(child: _dateField())
        ]),
        const SizedBox(height: 12),
        _channelRow(),
        const SizedBox(height: 12),
        _field('商家', _merchant, '选填'),
      ]);

  /// 品类：手填（不再预设狮子头/南疆石等，用户自己输入，文玩页按此名称统计）
  Widget _categoryField() =>
      _field('品类（手填）', _categoryCtl, '如：南疆石 / 狮子头 / 四座楼');

  /// 入手平台：下拉菜单（CI 反馈 #6 —— 原型是 select，之前被做成按钮，改回下拉）
  Widget _channelRow() => NeuSelect(
        label: '入手平台',
        current: _channel,
        options: channels,
        onPick: (v) => setState(() => _channel = v),
      );

  Widget _step2() => Column(children: [
        _sizeGrid(),
        const SizedBox(height: 12),
        _field('重量(g)', _weight, '0', isNum: true),
        const SizedBox(height: 12),
        _patinaSwitchRow(),
        const SizedBox(height: 12),
        _coverPicker(),
        const SizedBox(height: 12),
        // 走色只在「新增」时随件写入；编辑模式选了图也不会保存，
        // 原来两个控件照常显示会让壹以为存上了 —— 这里改成显式引导。
        if (widget.editWalnut == null) ...[
          _patinaPicker(),
          // 选完走色图必须能看到缩略图、能点开看大图（原来只有一行「已选 N 张」，
          // 选错了既看不见也改不了）
          if (_patina.isNotEmpty) ...[
            const SizedBox(height: 10),
            _patinaGrid(),
          ],
          const SizedBox(height: 12),
          _field('走色记录日期', _patinaDateCtl, '如 2026-10-04，可改'),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('走色照片请在详情页右上角「＋走色」添加',
                style: TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
          ),
        const SizedBox(height: 12),
        _field('备注', _remark, '选填'),
      ]);

  Widget _sizeGrid() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('六面尺寸(mm)', style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _field('左·边', _lBian, '0', isNum: true)),
      const SizedBox(width: 8),
      Expanded(child: _field('左·肚', _lDu, '0', isNum: true)),
      const SizedBox(width: 8),
      Expanded(child: _field('左·高', _lGao, '0', isNum: true))
    ]),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _field('右·边', _rBian, '0', isNum: true)),
      const SizedBox(width: 8),
      Expanded(child: _field('右·肚', _rDu, '0', isNum: true)),
      const SizedBox(width: 8),
      Expanded(child: _field('右·高', _rGao, '0', isNum: true))
    ]),
  ]);

  Widget _patinaSwitchRow() => NeumorphicBox(
          radius: Tokens.rCard,
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _switch('全品', _full, (v) => setState(() {
                  _full = v;
                  final c = Validate.coerce(_full, _repaired);
                  _full = c.full;
                  _repaired = c.repaired;
                })),
            _switch('有修', _repaired, (v) => setState(() {
                  _repaired = v;
                  final c = Validate.coerce(_full, _repaired);
                  _full = c.full;
                  _repaired = c.repaired;
                })),
            _switch('有黄', _yellow, (v) => setState(() => _yellow = v)),
          ]));

  Widget _switch(String label, bool v, ValueChanged<bool> on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(color: Tokens.text)),
        const Spacer(),
        NeuSwitch(value: v, onChanged: on)
      ]));

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

  Widget _patinaPicker() => GestureDetector(
          onTap: () async {
            final xs = await pickImagesFromSheet(context, multiple: true);
            if (xs.isNotEmpty) setState(() => _patina.addAll(xs));
          },
          child: NeumorphicBox(
              radius: Tokens.rCard,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.collections, color: Tokens.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      _patina.isEmpty
                          ? '添加走色记录图（可多张）'
                          : '已选 ${_patina.length} 张走色图',
                      style: TextStyle(color: Tokens.text)),
                ),
                Icon(Icons.chevron_right, color: Tokens.muted, size: 20),
              ])));

  /// 已选走色图缩略图：点开看大图，右上角 × 移除该张
  Widget _patinaGrid() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < _patina.length; i++)
            Stack(children: [
              GestureDetector(
                onTap: () => _preview(_patina, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(_patina[i].path),
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _patina.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]),
        ],
      );

  /// 已选图片缩略图；点按图片本身可看大图
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

  Widget _field(String label, TextEditingController c, String hint,
          {bool isNum = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 6),
        NeuTextField(
            hint: hint,
            controller: c,
            keyboardType: isNum ? TextInputType.number : null),
      ]);

  /// 购买日期：手动文本填入（不点选日历）
  Widget _dateField() => _field('购买日期', _buyDateCtl, '如 2026-10-04');

  Widget _actions(BuildContext context) => Row(children: [
        if (_step == 2)
          Expanded(child: NeuButton(label: '上一步', onTap: () => setState(() => _step = 1))),
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
    final e = widget.editWalnut;
    final code = e?.code ??
        CodeGen.format('核桃', _buyDateCtl.text,
            await WalnutDao.maxSeqSameDay(_buyDateCtl.text));
    final coverPath = e?.coverPath ?? '';
    final w = Walnut(
        id: e?.id,
        code: code,
        name: _name.text.trim(),
        category: _categoryCtl.text.trim(),
        variety: '',
        price: _d(_price),
        lBian: _d(_lBian),
        lDu: _d(_lDu),
        lGao: _d(_lGao),
        rBian: _d(_rBian),
        rDu: _d(_rDu),
        rGao: _d(_rGao),
        weight: _d(_weight),
        buyDate: _buyDateCtl.text,
        channel: _channel,
        merchant: _merchant.text.trim(),
        full: _full,
        repaired: _repaired,
        yellow: _yellow,
        remark: _remark.text.trim(),
        coverPath: coverPath);
    int? id;
    if (e != null) {
      await WalnutDao.update(w);
      id = e.id;
    } else {
      id = await WalnutDao.insert(w);
    }
    if (_cover != null && id != null) {
      final rel = await ImageStore.save('walnut', id, File(_cover!.path));
      // 换了封面就把旧封面文件删掉（先存新的、再删旧的，避免新图失败白删）
      if (e != null && e.coverPath.isNotEmpty && e.coverPath != rel) {
        await ImageStore.deleteFile(e.coverPath);
      }
      await WalnutDao.update(Walnut(
          id: id,
          code: code,
          name: w.name,
          category: w.category,
          variety: w.variety,
          price: w.price,
          lBian: w.lBian,
          lDu: w.lDu,
          lGao: w.lGao,
          rBian: w.rBian,
          rDu: w.rDu,
          rGao: w.rGao,
          weight: w.weight,
          buyDate: w.buyDate,
          channel: w.channel,
          merchant: w.merchant,
          full: w.full,
          repaired: w.repaired,
          yellow: w.yellow,
          remark: w.remark,
          coverPath: rel));
    }
    // 编辑模式不改走色图（保留原图）；新增模式才写入
    if (_patina.isNotEmpty && id != null) {
      final rels = <String>[];
      for (final f in _patina) {
        rels.add(await ImageStore.save('patina', id, File(f.path)));
      }
      await PatinaDao.insert(Patina(walnutId: id, date: _patinaDateCtl.text, images: rels));
    }
    refreshCollection(ref);
    if (mounted) Navigator.pop(context);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
