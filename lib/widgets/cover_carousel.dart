import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/image_store.dart';
import '../theme/tokens.dart';
import '../../logic/router.dart';

/// 身份卡顶部图片自动流转（CI 反馈 #6）：封面 + 走色图一起轮播，每 4 秒切一张。
/// 点任意一张 → 打开全屏大图（可左右滑、可缩放）。
class CoverCarousel extends StatefulWidget {
  final List<String> rels;
  final double height;

  const CoverCarousel({
    super.key,
    required this.rels,
    this.height = 210,
  });

  @override
  State<CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<CoverCarousel> {
  final PageController _pc = PageController();
  Timer? _timer;
  List<String> _abs = [];
  bool _loaded = false;
  int _idx = 0;
  double? _aspect; // 首图宽高比（宽/高），用于自适应高度让整图可见

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CoverCarousel old) {
    super.didUpdateWidget(old);
    if (old.rels.length != widget.rels.length) _load();
  }

  Future<void> _load() async {
    _timer?.cancel();
    final out = <String>[];
    for (final r in widget.rels) {
      if (r.isEmpty) continue;
      try {
        final p = await ImageStore.fullPath(r);
        if (File(p).existsSync()) out.add(p);
      } catch (_) {}
    }
    // 取首图宽高比（小尺寸解码，省内存），用于把轮播高度撑到整图可见：
    // PC 宽窗口下固定 210 高 + BoxFit.cover 会把图裁成中间一条横带
    double? aspect;
    if (out.isNotEmpty) {
      try {
        final codec = await ui.instantiateImageCodec(
          await File(out.first).readAsBytes(),
          targetWidth: 64,
        );
        final frame = await codec.getNextFrame();
        aspect = frame.image.width / frame.image.height;
        codec.dispose();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _abs = out;
      _aspect = aspect;
      _loaded = true;
      if (_idx >= out.length) _idx = 0;
    });
    if (out.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || _abs.isEmpty) return;
        final next = (_idx + 1) % _abs.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return _box(child: _ph());
    if (_abs.isEmpty) {
      return _box(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: Tokens.faint, size: 34),
              const SizedBox(height: 6),
              Text('还没有图片',
                  style:
                      TextStyle(color: Tokens.faint, fontSize: Tokens.fsHint)),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, cons) {
      // 高度自适应：最少 widget.height；按首图宽高比撑到整图可见，封顶 480。
      // 手机端几乎等于原效果；PC 宽窗口不再把图裁成一条。
      double h = widget.height;
      final a = _aspect;
      if (a != null && a > 0 && cons.maxWidth.isFinite) {
        final raw = cons.maxWidth / a;
        h = raw < widget.height
            ? widget.height
            : (raw > 480.0 ? 480.0 : raw);
      }
      return SizedBox(
      height: h,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          // BoxFit.contain 留白处露出卡片底色
          Positioned.fill(child: ColoredBox(color: Tokens.ph1)),
          PageView.builder(
            controller: _pc,
            itemCount: _abs.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _open(i),
              child: Image.file(File(_abs[i]),
                  width: double.infinity,
                  height: h,
                  fit: BoxFit.contain),
            ),
          ),
          if (_abs.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _abs.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _idx ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _idx
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ]),
      ),
      );
    });
  }

  Widget _box({required Widget child}) => Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Tokens.ph1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _ph() => Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Tokens.faint)),
      );

  void _open(int i) {
    AppRouter.toImageViewer(context, _abs, i);
  }
}

// _CarouselViewer 已移除：轮播大图复用 ImageViewer（见 AppRouter.toImageViewer）

/// 把相对路径批量解析为绝对路径（详情页/大图复用）
Future<List<String>> resolvePaths(List<String> rels) async {
  final out = <String>[];
  for (final r in rels) {
    if (r.isEmpty) continue;
    try {
      final p = await ImageStore.fullPath(r);
      if (File(p).existsSync()) out.add(p);
    } catch (_) {}
  }
  return out;
}

/// 已落盘图片 → XFile（给 ImageViewer 用）
List<XFile> toXFiles(List<String> abs) => abs.map((p) => XFile(p)).toList();
