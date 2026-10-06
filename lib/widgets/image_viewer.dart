import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

/// 把一张图存进手机相册（壹诉求：明年翻到走色图觉得好，能直接存到手机）。
/// Android 10+ 走 MediaStore 不需要存储权限；iOS 需要在 Info.plist 声明（本工程只出 Android 包）。
Future<void> saveImageToGallery(BuildContext context, String path) async {
  try {
    await Gal.putImage(path, album: 'ZHANGYIWW');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到手机相册「ZHANGYIWW」相簿')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }
}

/// 可缩放单图：双指捏合 + 双击切换 2.5 倍/原尺寸。
/// 双击缩放以视口中心为锚点（直接 scale 会以左上角为锚点，图会飘走）。
class ZoomableImage extends StatefulWidget {
  final String path;
  const ZoomableImage({super.key, required this.path});

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  static const double _zoom = 2.5;
  final TransformationController _tc = TransformationController();

  void _toggle(Size vp) {
    final s = _tc.value.getMaxScaleOnAxis();
    if (s > 1.5) {
      _tc.value = Matrix4.identity();
    } else {
      final m = Matrix4.identity();
      m
        ..setEntry(0, 3, vp.width / 2 * (1 - _zoom))
        ..setEntry(1, 3, vp.height / 2 * (1 - _zoom))
        ..multiply(Matrix4.diagonal3Values(_zoom, _zoom, 1));
      _tc.value = m;
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
        return InteractiveViewer(
          transformationController: _tc,
          minScale: 1,
          maxScale: 5,
          panEnabled: true,
          scaleEnabled: true,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () => _toggle(Size(cons.maxWidth, cons.maxHeight)),
            child: Center(
              child: Image.file(File(widget.path),
                  fit: BoxFit.contain, filterQuality: FilterQuality.high),
            ),
          ),
        );
      });
}

/// 全屏大图预览：支持左右滑动切换、点击空白关闭
///
/// PC 桌面端补充：左右箭头按钮 + 键盘 ←/→ 翻页（手机端触摸滑动不受影响）。
class ImageViewer extends StatefulWidget {
  final List<XFile> files;
  final int initial;
  const ImageViewer({super.key, required this.files, this.initial = 0});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PageController _pc =
      PageController(initialPage: widget.initial.clamp(0, widget.files.length - 1));
  late int _idx = widget.initial.clamp(0, widget.files.length - 1);

  /// 多张时才需要翻页控件。
  bool get _multi => widget.files.length > 1;

  @override
  void initState() {
    super.initState();
    // PC 端：←/→ 翻页，Esc 关闭。必须在 initState 注册、dispose 注销，否则泄漏。
    if (_multi) {
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return true;
    }
    return false;
  }

  /// 相对翻页（±1），边界处不越界。
  void _go(int delta) {
    if (!_multi) return;
    final next = (_idx + delta).clamp(0, widget.files.length - 1);
    if (next == _idx) return;
    setState(() => _idx = next);
    _pc.animateToPage(next,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    if (_multi) {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _pc,
          itemCount: widget.files.length,
          onPageChanged: (i) => setState(() => _idx = i),
          itemBuilder: (_, i) => ZoomableImage(path: widget.files[i].path),
        ),
        // 关闭按钮
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          right: 12,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        // 左右翻页箭头（PC 端鼠标可点；手机端用滑动，不遮挡内容）
        if (_multi) ...[
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(child: _navArrow(Icons.chevron_left, () => _go(-1))),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(child: _navArrow(Icons.chevron_right, () => _go(1))),
          ),
        ],
        // 保存到手机相册（当前这一张）
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 24,
          left: 0,
          right: 0,
          child: Center(
            child: InkWell(
              onTap: () => saveImageToGallery(context, widget.files[_idx].path),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.save_alt, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('保存到手机',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// 左右箭头按钮；已到边界时淡化并禁用点击。
  Widget _navArrow(IconData icon, VoidCallback onTap) {
    final enabled = icon == Icons.chevron_left ? _idx > 0 : _idx < widget.files.length - 1;
    return Opacity(
      opacity: enabled ? 1 : 0.25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
