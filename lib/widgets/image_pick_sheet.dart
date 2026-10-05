import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/tokens.dart';
import '../theme/nu.dart';

/// 底部弹出「拍照 / 从相册选择 / 取消」操作菜单。
/// 单选（封面）两种来源都可选；多选（走色图）只能从相册，故不显示「拍照」。
/// 返回已选文件列表；用户取消时返回空列表。
Future<List<XFile>> pickImagesFromSheet(
  BuildContext context, {
  bool multiple = false,
}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetTitle(ctx, multiple ? '添加走色图' : '选择图片'),
          if (!multiple)
            _sheetItem(ctx, Icons.photo_camera_outlined, '拍照', () =>
                Navigator.pop(ctx, ImageSource.camera)),
          _sheetItem(ctx, Icons.photo_library_outlined, '从相册选择', () =>
              Navigator.pop(ctx, ImageSource.gallery)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: NeuButton(
              label: '取消',
              onTap: () => Navigator.pop(ctx),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );

  if (src == null) return const [];
  final picker = ImagePicker();
  if (multiple) {
    final xs = await picker.pickMultiImage();
    return xs;
  }
  final one = await picker.pickImage(source: src);
  return one == null ? const [] : [one];
}

Widget _sheetTitle(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: TextStyle(
                color: Tokens.text,
                fontSize: Tokens.fsEmph,
                fontWeight: FontWeight.bold)),
      ),
    );

Widget _sheetItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
    ListTile(
      leading: Icon(icon, color: Tokens.accent),
      title: Text(label, style: TextStyle(color: Tokens.text)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
