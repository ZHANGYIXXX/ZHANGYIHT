import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_store.dart';
import 'cos_client.dart';
import 'local_index.dart';
import 'models.dart';

/// 云同步编排（PC 与手机共用）。
///
/// 策略：**单向 本地 → 云端 备份，本地优先，原图原文件**。
/// 流程：读配置 → 建本地索引 → 差异上传 → 远端大小校验 → 汇总。
///
/// 远端布局：<remoteBasePath>/<设备子目录>/<相对路径>
/// 每设备独立子目录，PC 与手机互不覆盖（沿用删除前的安全快照设计，
/// 避免两台上传同一相对路径时互相踩踏）。
class CloudSyncOrchestrator {
  /// 进度回调：[done] 已完成数 / [total] 总数 / [file] 当前文件名
  final void Function(int done, int total, String file)? onProgress;

  CloudSyncOrchestrator({this.onProgress});

  /// 当前设备的远端子目录名（pc / phone / other）。
  static String deviceSubdir() {
    if (Platform.isWindows) return 'pc';
    if (Platform.isAndroid) return 'phone';
    return 'other';
  }

  /// 一键全量备份本地数据目录 [localRoot] 到腾讯云 COS。
  Future<SyncResult> backupAll(Directory localRoot) async {
    final cfg = await SyncConfigStore.load();
    if (cfg == null) {
      throw StateError('未配置云同步，请先在设置里完成配置向导');
    }
    final client = CosClient(cfg);

    // 本地索引（跳过 .tmp 等临时文件）
    final idx = await LocalFileIndex.build(
      localRoot,
      filter: (f) => !f.path.endsWith('.tmp'),
    );

    var r = const SyncResult();
    var done = 0;
    for (final e in idx.values) {
      onProgress?.call(done, idx.length, e.relativePath);
      final local = File(p.join(localRoot.path, e.relativePath));
      final key = client.objectKey('${deviceSubdir()}/${e.relativePath}');
      try {
        // 先查远端大小：一致则跳过，避免重复上传原图
        final remoteSize = await client.headSize(key);
        if (remoteSize == e.size) {
          r += const SyncResult(skipped: 1);
        } else {
          await client.uploadFile(local, key);
          // 上传后校验远端大小与本地一致（低成本完整性验证）
          final after = await client.headSize(key);
          if (after == e.size) {
            r += const SyncResult(uploaded: 1);
          } else {
            r += SyncResult(
              failed: 1,
              errors: ['${e.relativePath}: 大小不一致(本地 ${e.size} / 云端 $after)'],
            );
          }
        }
      } catch (err) {
        // 失败降级：单文件失败不中断整体
        r += SyncResult(failed: 1, errors: ['${e.relativePath}: $err']);
      }
      done++;
    }
    client.dispose();
    return r;
  }

  /// 上传后校验：抽查云端文件大小 == 本地（低成本完整性验证）。
  Future<bool> verifyRemoteSizes(Directory localRoot) async {
    final cfg = await SyncConfigStore.load();
    if (cfg == null) return false;
    final client = CosClient(cfg);
    final idx = await LocalFileIndex.build(localRoot);
    var ok = true;
    for (final e in idx.values) {
      final key = client.objectKey('${deviceSubdir()}/${e.relativePath}');
      final size = await client.headSize(key);
      if (size != e.size) {
        ok = false;
        break;
      }
    }
    client.dispose();
    return ok;
  }

  /// 从云端恢复：把云端 [deviceSubdir] 的全部文件下载到 [localRoot]。
  ///
  /// 用于换机恢复：先关闭数据库句柄（由调用方负责），再逐文件写回。
  /// 本地已存在且大小一致的文件会跳过。
  Future<SyncResult> restoreAll(
    Directory localRoot,
    Map<String, ({int size})> remoteEntries,
  ) async {
    final cfg = await SyncConfigStore.load();
    if (cfg == null) throw StateError('未配置云同步');
    final client = CosClient(cfg);
    var r = const SyncResult();
    var done = 0;
    for (final e in remoteEntries.entries) {
      onProgress?.call(done, remoteEntries.length, e.key);
      final rel = e.key;
      final dest = File(p.join(localRoot.path, rel));
      try {
        if (await dest.exists() && await dest.length() == e.value.size) {
          r += const SyncResult(skipped: 1);
        } else {
          await client.downloadObject(
            client.objectKey('${deviceSubdir()}/$rel'),
            dest,
          );
          r += const SyncResult(downloaded: 1);
        }
      } catch (err) {
        r += SyncResult(failed: 1, errors: ['$rel: $err']);
      }
      done++;
    }
    client.dispose();
    return r;
  }
}