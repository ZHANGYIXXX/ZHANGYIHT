import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../data/models/patina.dart';
import '../../data/daos/patina_dao.dart';
import '../../data/image_store.dart';
import '../../widgets/image_pick_sheet.dart';
import '../../widgets/image_viewer.dart';

/// 新增走色记录（CI 反馈 #5：详情页右上角 ⊕ 直接进入）
/// 内容严格 = 日期 + 图片（≤6 张），无备注（壹 2026-10 拍板）
class AddPatinaPage extends ConsumerStatefulWidget {
  final int walnutId;
  const AddPatinaPage({super.key, required this.walnutId});

  @override
  ConsumerState<AddPatinaPage> createState() => _AddPatinaPageState();
}

class _AddPatinaPageState extends ConsumerState<AddPatinaPage> {
  static const int _max = 6;
  late final TextEditingController _date;
  final List<XFile> _pics = [];
  bool _saving = false;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: _today());
  }

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: _askExit, child: Icon(Icons.arrow_back, color: Tokens.text)),
          title: Text('添加走色记录',
              style: TextStyle(
                  color: Tokens.text,
                  fontSize: Tokens.fsEmph,
                  fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('记录日期',
                          style: TextStyle(
                              color: Tokens.muted, fontSize: Tokens.fsHint)),
                      const SizedBox(height: 6),
                      NeuTextField(hint: '如 2026-10-04', controller: _date),
                      const SizedBox(height: 18),
                      Row(children: [
                        Text('走色照片',
                            style: TextStyle(
                                color: Tokens.muted, fontSize: Tokens.fsHint)),
                        const Spacer(),
                        Text('${_pics.length} / $_max',
                            style: TextStyle(
                                color: Tokens.faint, fontSize: Tokens.fsHint)),
                      ]),
                      const SizedBox(height: 10),
                      _grid(),
                    ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: NeuButton(
                  label: _saving ? '保存中…' : '保存', onTap: _saving ? null : _save),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _grid() {
    final cells = <Widget>[];
    for (int i = 0; i < _pics.length; i++) {
      cells.add(_pic(i));
    }
    if (_pics.length < _max) cells.add(_addBtn());
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cells
          .map((w) => SizedBox(
              width: (MediaQuery.of(context).size.width - 32 - 20) / 3,
              height: (MediaQuery.of(context).size.width - 32 - 20) / 3,
              child: w))
          .toList(),
    );
  }

  Widget _pic(int i) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _preview(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_pics[i].path), fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _pics.removeAt(i)),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ]);

  Widget _addBtn() => GestureDetector(
        onTap: _pick,
        child: NeumorphicBox(
          state: NeuState.inset,
          radius: 12,
          child: Center(
            child: Icon(Icons.add_a_photo_outlined,
                color: Tokens.muted, size: 26),
          ),
        ),
      );

  Future<void> _pick() async {
    final room = _max - _pics.length;
    if (room <= 0) {
      _toast('最多 $_max 张');
      return;
    }
    final xs = await pickImagesFromSheet(context, multiple: true);
    if (xs.isEmpty) return;
    setState(() => _pics.addAll(xs.take(room)));
  }

  void _preview(int i) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ImageViewer(files: _pics, initial: i),
    );
  }

  Future<void> _save() async {
    if (_pics.isEmpty) {
      _toast('至少选 1 张走色照片');
      return;
    }
    final date = _date.text.trim();
    if (date.isEmpty) {
      _toast('请填写记录日期');
      return;
    }
    setState(() => _saving = true);
    final rels = <String>[];
    for (final f in _pics) {
      rels.add(await ImageStore.save('patina', widget.walnutId, File(f.path)));
    }
    await PatinaDao.insert(Patina(
        ownerType: 'walnut', ownerId: widget.walnutId, date: date, images: rels));
    refreshCollection(ref);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _askExit() async {
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('是否保存'),
        content: const Text('这条走色记录还没保存，要保存后退出吗？'),
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
      await _save();
      return; // 没图/没日期时 _save 会提示并留在页面
    }
    if (mounted) Navigator.pop(context);
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
