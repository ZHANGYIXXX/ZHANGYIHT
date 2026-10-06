import 'dart:io';
import 'package:path/path.dart' as p;
import '../logic/platform_paths.dart';

// 原图文件系统存储（字节级不压缩）
// 路径结构：<应用文档>/yizhanghe/images/{kind}/{id}/文件名
// 数据库只存相对路径 images/{kind}/{id}/文件名
class ImageStore {
  // 批量保存（走色一次最多 6 张）时若只用毫秒时间戳，同一毫秒内的多张图会
  // 落到同一个文件名、互相覆盖 → 照片直接丢失。故补微秒 + 进程内自增序号兜底。
  static int _seq = 0;

  static Future<String> _dirFor(String kind, int id) async {
    final base = await PlatformPaths.appDataDir();
    final dir =
        Directory(p.join(base.path, 'images', kind, id.toString()));
    await dir.create(recursive: true);
    return dir.path;
  }

  // 保存原图，返回相对路径（如 images/walnut/3/1696000000000.jpg）
  static Future<String> save(String kind, int id, File src) async {
    final dir = await _dirFor(kind, id);
    final ts = DateTime.now().microsecondsSinceEpoch;
    final seq = ++_seq;
    final name = '${ts}_$seq${p.extension(src.path)}';
    final dest = File(p.join(dir, name));
    await src.copy(dest.path); // 原样复制，不压缩
    return 'images/$kind/$id/$name';
  }

  // 删除单张原图（换封面/删走色图时清理旧文件，避免磁盘只增不减）
  static Future<void> deleteFile(String rel) async {
    if (rel.isEmpty) return;
    final base = await PlatformPaths.appDataDir();
    final f = File(p.join(base.path, rel));
    if (await f.exists()) await f.delete();
  }

  // 删除某藏品全部原图（删藏品时调用）
  static Future<void> deleteDir(String kind, int id) async {
    final base = await PlatformPaths.appDataDir();
    final dir =
        Directory(p.join(base.path, 'images', kind, id.toString()));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // 相对路径 → 绝对路径（Image.file 用）
  static Future<String> fullPath(String rel) async {
    final base = await PlatformPaths.appDataDir();
    return p.join(base.path, rel);
  }
}
