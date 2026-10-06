import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../sync/models.dart';
import '../sync/zspace_adapter.dart';
import '../sync/sync_index.dart';
import '../sync/resume_upload.dart';
import '../sync/config_store.dart';

/// 同步编排（PC 与华为共用）。
///
/// 策略（V2 清单固定）：**单向 本地 → NAS 备份，本地优先，原图原文件**。
/// 流程：读配置 → 建索引 → 远端目录就绪 → 差异上传（断点续传）→ 完整性校验 → 汇总。
class SyncOrchestrator {
  /// 进度回调：[done] 已完成文件数 / [total] 总数 / [file] 当前文件名
  final void Function(int done, int total, String file)? onProgress;

  SyncOrchestrator({this.onProgress});

  /// 一键全量备份本地数据目录 [localRoot] 到 NAS。
  Future<SyncResult> backupAll(Directory localRoot) async {
    final cfg = await SyncConfigStore.load();
    if (cfg == null) throw StateError('未配置 NAS 同步，请先在设置里完成配置向导');
    final client = await ZSpaceAdapter.connect(cfg);
    final uploader = ResumeUploader(client);

    // 远端根：/<base>/<设备子目录>（pc / pura_xmax）
    final sub = Platform.isWindows ? 'pc' : (Platform.isAndroid ? 'pura_xmax' : 'other');
    final remoteRoot = '${cfg.remoteBasePath}/$sub';
    await client.mkcolRecursive(remoteRoot);

    // 本地索引（跳过 .tmp 等临时文件）
    final idx = await SyncIndex.build(
      localRoot,
      filter: (f) => !f.path.endsWith('.tmp'),
    );

    var r = const SyncResult();
    var done = 0;
    for (final e in idx.values) {
      onProgress?.call(done, idx.length, e.relativePath);
      final local = File(p.join(localRoot.path, e.relativePath));
      final remote = '$remoteRoot/${e.relativePath}';
      try {
        // 确保远端父目录存在
        final dir = remote.substring(0, remote.lastIndexOf('/'));
        await client.mkcolRecursive(dir);
        final n = await uploader.upload(local, remote);
        if (n == 0) {
          r += const SyncResult(skipped: 1);
        } else {
          r += const SyncResult(uploaded: 1);
        }
      } catch (err) {
        // 失败降级：单文件失败不中断整体（清单 §1 失败降级）
        r += SyncResult(failed: 1, errors: ['${e.relativePath}: $err']);
      }
      done++;
    }
    client.dispose();
    return r;
  }

  /// 上传后校验：抽查远端文件大小 == 本地（低成本完整性验证）。
  Future<bool> verifyRemoteSizes(Directory localRoot) async {
    final cfg = await SyncConfigStore.load();
    if (cfg == null) return false;
    final client = await ZSpaceAdapter.connect(cfg);
    final sub = Platform.isWindows ? 'pc' : (Platform.isAndroid ? 'pura_xmax' : 'other');
    final remoteRoot = '${cfg.remoteBasePath}/$sub';
    final idx = await SyncIndex.build(localRoot);
    var ok = true;
    for (final e in idx.values) {
      final remote = '$remoteRoot/${e.relativePath}';
      try {
        final size = await client.headSize(remote);
        if (size != e.size) {
          ok = false;
          break;
        }
      } catch (_) {
        ok = false;
        break;
      }
    }
    client.dispose();
    return ok;
  }
}
