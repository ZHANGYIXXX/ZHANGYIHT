import 'dart:io';
import 'package:crypto/crypto.dart';
import 'models.dart';
import 'filename_normalizer.dart';

/// 完整性校验。
///
/// 上传前 / 下载后用于确认「字节级一致」，避免传输损坏或中断导致的静默坏文件。
class Integrity {
  /// 计算本地文件的 SHA-256（小写十六进制）。
  static Future<String> hashFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 本地文件是否与索引条目一致（按 sha256 比对）。
  static Future<bool> localMatchesEntry(File file, SyncFileEntry entry) async {
    if (!await file.exists()) return false;
    if (await file.length() != entry.size) return false;
    final h = await hashFile(file);
    return h == entry.sha256;
  }

  /// 比对两端是否内容一致（先比大小，大小一致再比哈希）。
  /// [remoteSize] / [remoteSha256] 可来自 PROPFIND 的 getcontentlength 或重算。
  static bool contentMatches({
    required int localSize,
    required String localSha256,
    required int remoteSize,
    String? remoteSha256,
  }) {
    if (localSize != remoteSize) return false;
    if (remoteSha256 != null && remoteSha256.isNotEmpty) {
      return localSha256 == remoteSha256;
    }
    return true; // 无远端哈希时，仅靠大小判断
  }

  /// 规范化相对路径是否与某条目匹配（索引 key 一致性）。
  static bool pathMatches(String relativePath, SyncFileEntry entry) {
    return FilenameNormalizer.normalizeRelative(relativePath) == entry.relativePath;
  }
}
