import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 原图文件系统存储（字节级不压缩）
// 路径结构：<应用文档>/yizhanghe/images/{kind}/{id}/文件名
// 数据库只存相对路径 images/{kind}/{id}/文件名
class ImageStore {
  static Future<String> _dirFor(String kind, int id) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
        p.join(base.path, 'yizhanghe', 'images', kind, id.toString()));
    await dir.create(recursive: true);
    return dir.path;
  }

  // 保存原图，返回相对路径（如 images/walnut/3/1696000000000.jpg）
  static Future<String> save(String kind, int id, File src) async {
    final dir = await _dirFor(kind, id);
    final name = '${DateTime.now().millisecondsSinceEpoch}${p.extension(src.path)}';
    final dest = File(p.join(dir, name));
    await src.copy(dest.path); // 原样复制，不压缩
    return 'images/$kind/$id/$name';
  }

  // 删除某藏品全部原图（删藏品时调用）
  static Future<void> deleteDir(String kind, int id) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
        p.join(base.path, 'yizhanghe', 'images', kind, id.toString()));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // 相对路径 → 绝对路径（Image.file 用）
  static Future<String> fullPath(String rel) async {
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, 'yizhanghe', rel);
  }
}
