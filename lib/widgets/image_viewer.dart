import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/tokens.dart';

/// 全屏大图预览：支持左右滑动切换、点击空白关闭
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

  @override
  void dispose() {
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
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Image.file(File(widget.files[i].path), fit: BoxFit.contain),
            ),
          ),
        ),
        // 顶部计数
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '${_idx + 1} / ${widget.files.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
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
      ]),
    );
  }
}
