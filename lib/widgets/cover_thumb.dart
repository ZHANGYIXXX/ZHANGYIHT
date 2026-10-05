import 'dart:io';
import 'package:flutter/material.dart';
import '../data/image_store.dart';
import '../theme/tokens.dart';

// 封面缩略图：库里存的是相对路径，需解析成绝对路径再用 Image.file 展示
class CoverThumb extends StatelessWidget {
  final String? rel;
  final double size;
  const CoverThumb({super.key, this.rel, this.size = 56});

  @override
  Widget build(BuildContext context) {
    if (rel == null || rel!.isEmpty) return _placeholder();
    return FutureBuilder<String>(
      future: ImageStore.fullPath(rel!),
      builder: (c, s) {
        if (s.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(s.data!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Tokens.inSm,
        ),
        child: Icon(Icons.image_outlined,
            color: Tokens.faint, size: 22),
      );
}
