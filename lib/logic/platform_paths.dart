import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 跨平台目录统一层（评审意见 B13 / P0 基础项）。
///
/// 把「备份基目录 / 备份根目录 / 应用文档目录」三处取值收敛到一处，
/// 让备份、导入导出、云同步、数据库与原图存储都走同一套逻辑，
/// 不再各自重复写 Platform.isWindows / getExternalStorageDirectory 的 try/catch 坑。
///
/// 取值规则：
/// - Windows：下载文件夹（Downloads）
/// - Android：外部存储（getExternalStorageDirectory，但它在 Windows 上会直接抛
///   UnimplementedError 而非返回 null，所以必须 try/catch，不能 ?? 兜底）
/// - 其余平台：应用文档目录（getApplicationDocumentsDirectory）
class PlatformPaths {
  /// 应用文档根：<文档目录>/yizhanghe。数据库（app.db）与原图都落在它下面。
  static Future<Directory> appDataDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'yizhanghe'));
  }

  /// 备份基目录（导出写到哪）：
  /// Windows=下载；Android=外部存储；其余=文档目录。
  static Future<Directory> backupBase() async {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        final dl = Directory(p.join(home, 'Downloads'));
        if (await dl.exists()) return dl;
      }
    }
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return ext;
      } catch (_) {
        // Windows 上 getExternalStorageDirectory 直接抛 UnimplementedError，忽略走兜底
      }
    }
    return getApplicationDocumentsDirectory();
  }

  /// 备份根目录：在候选目录里找已存在的「壹ZHANG核备份」。
  /// 都找不到（首次还没导出过）返回 null。
  static Future<Directory?> backupRoot() async {
    final candidates = <Directory>[];
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) candidates.add(Directory(p.join(home, 'Downloads')));
    }
    if (Platform.isAndroid) {
      try {
        final d = await getExternalStorageDirectory();
        if (d != null) candidates.add(d);
      } catch (_) {
        // 同上，忽略
      }
    }
    candidates.add(await getApplicationDocumentsDirectory());
    for (final d in candidates) {
      final r = Directory(p.join(d.path, '壹ZHANG核备份'));
      if (await r.exists()) return r;
    }
    return null;
  }
}
