import 'dart:io';
import 'package:crypto/crypto.dart';
import 'models.dart';
import 'filename_normalizer.dart';

/// 本地文件 SHA-256 索引构建。
///
/// 对本地某个根目录做全量扫描，产出「规范化相对路径 -> [SyncFileEntry]」的稳定映射。
/// PC 端与华为端用同一套规则构建，从而能互相识别「同一份文件」并比对差异。
class SyncIndex {
  /// 扫描 [rootDir]，返回规范化相对路径为 key 的索引。
  /// [filter] 可选，返回 false 的文件会被跳过。
  static Future<Map<String, SyncFileEntry>> build(
    Directory rootDir, {
    bool Function(File file)? filter,
  }) async {
    final map = <String, SyncFileEntry>{};
    if (!await rootDir.exists()) return map;
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (filter != null && !filter(entity)) continue;
      final rel = entity.path.substring(rootDir.path.length);
      final normRel = FilenameNormalizer.normalizeRelative(rel);
      final bytes = await entity.readAsBytes();
      final hash = sha256.convert(bytes).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final stat = await entity.stat();
      map[normRel] = SyncFileEntry(
        relativePath: normRel,
        sha256: hash,
        size: bytes.length,
        mtime: stat.modified.millisecondsSinceEpoch,
      );
    }
    return map;
  }
}
