import 'dart:io';
import 'webdav_client.dart';

/// 断点续传上传。
///
/// 流程：
///  1) HEAD 远端已存在大小；
///  2) 若远端已有部分数据且与本地前缀一致（简化处理：仅按大小续传），则从偏移处继续 PUT；
///  3) 若服务端不支持 Content-Range（返回非 2xx），回退为整文件重传。
class ResumeUploader {
  final WebDavClient client;
  final int chunkSize;

  ResumeUploader(this.client, {this.chunkSize = 1024 * 1024});

  /// 把本地 [file] 上传到远端 [remotePath]。
  /// 返回实际上传的字节数（用于统计）。失败抛 [WebDavException]。
  Future<int> upload(File file, String remotePath) async {
    final total = await file.length();
    final existing = await client.headSize(remotePath);

    // 已完整 -> 跳过
    if (existing == total && total > 0) return 0;

    // 续传偏移（仅在 0 < existing < total 时尝试；其它情况整传）
    var offset = (existing > 0 && existing < total) ? existing : 0;

    final raf = await file.open(mode: FileMode.read);
    try {
      if (offset > 0) {
        await raf.setPosition(offset);
      }
      while (offset < total) {
        final end = (offset + chunkSize < total) ? offset + chunkSize : total;
        final chunk = await raf.read(end - offset);
        try {
          await client.put(remotePath, chunk, offset: offset, total: total);
        } on WebDavException {
          // 服务端不支持断点续传 -> 从 0 整传
          if (offset > 0) {
            offset = 0;
            await raf.setPosition(0);
            await client.put(remotePath, await file.readAsBytes(), offset: 0, total: total);
            return total;
          }
          rethrow;
        }
        offset = end;
      }
      return total;
    } finally {
      await raf.close();
    }
  }
}
