import 'dart:io';
import 'package:path/path.dart' as p;
import '../logic/platform_paths.dart';

// 原图文件系统存储（字节级不压缩）
// 路径结构：<应用文档>/yizhanghe/images/{段...}/文件名
//   - 封面等：images/{kind}/{id}/文件名          （kind = walnut | item）
//   - 走色图： images/patina/{ownerType}/{ownerId}/文件名
//     ownerType 段用于消「评审意见 8.4」指出的撞目录：核桃#N 与手串#N 的走色图
//     若都用 images/patina/{id} 会落到同一目录互相覆盖。加 ownerType 段后
//     images/patina/walnut/5 与 images/patina/item/5 互不干扰。
// 数据库只存相对路径。
class ImageStore {
  // 批量保存（走色一次最多 6 张）时若只用毫秒时间戳，同一毫秒内的多张图会
  // 落到同一个文件名、互相覆盖 → 照片直接丢失。故补微秒 + 进程内自增序号兜底。
  static int _seq = 0;

  // 拼出 images/ 下某目录的绝对路径（parts 为 kind/id 等段）
  static Future<String> _dirFor(List<String> parts) async {
    final base = await PlatformPaths.appDataDir();
    final dir = Directory(p.joinAll([base.path, 'images', ...parts]));
    await dir.create(recursive: true);
    return dir.path;
  }

  // 落盘一张原图，返回相对路径（如 images/walnut/3/1696000000000.jpg）
  static Future<String> _save(List<String> parts, File src) async {
    final dir = await _dirFor(parts);
    final ts = DateTime.now().microsecondsSinceEpoch;
    final seq = ++_seq;
    final name = '${ts}_$seq${p.extension(src.path)}';
    final dest = File(p.join(dir, name));
    await src.copy(dest.path); // 原样复制，不压缩
    return 'images/${parts.join('/')}/$name';
  }

  // 保存藏品封面等（kind = walnut | item）
  static Future<String> save(String kind, int id, File src) =>
      _save([kind, id.toString()], src);

  // 保存走色图（评审意见 8.4 泛化）：ownerType 段避免不同藏品类型 id 撞目录
  static Future<String> savePatina(String ownerType, int ownerId, File src) =>
      _save(['patina', ownerType, ownerId.toString()], src);

  // 删除单张原图（换封面/删走色图时清理旧文件，避免磁盘只增不减）
  static Future<void> deleteFile(String rel) async {
    if (rel.isEmpty) return;
    final base = await PlatformPaths.appDataDir();
    final f = File(p.join(base.path, rel));
    if (await f.exists()) await f.delete();
  }

  // 删除某目录（parts 段）
  static Future<void> _deleteDir(List<String> parts) async {
    final base = await PlatformPaths.appDataDir();
    final dir = Directory(p.joinAll([base.path, 'images', ...parts]));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // 删除某藏品全部封面原图（删藏品时调用）
  static Future<void> deleteDir(String kind, int id) =>
      _deleteDir([kind, id.toString()]);

  // 删除某 owner 全部走色原图（评审意见 8.4 泛化，按 ownerType 段隔离）
  static Future<void> deletePatinaDir(String ownerType, int ownerId) =>
      _deleteDir(['patina', ownerType, ownerId.toString()]);

  // 相对路径 → 绝对路径（Image.file 用）
  static Future<String> fullPath(String rel) async {
    final base = await PlatformPaths.appDataDir();
    return p.join(base.path, rel);
  }
}
