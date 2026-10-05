import 'webdav_client.dart';
import 'models.dart';

/// 极空间 Z2PRO 适配器。
///
/// 把用户友好的「IP / 端口 / 账号 / 密码 / 共享目录」转换成通用的 [SyncConfig]，
/// 并对极空间的若干习惯做适配：
///  - 默认 WebDAV 端口 5005（HTTPS 自签证书）；
///  - 多数固件要求 Digest 鉴权；
///  - 远端根目录约定为 /dav/<共享名>。
class ZSpaceAdapter {
  /// 由用户友好输入构造一个可用的 [SyncConfig]。
  /// [host] 可带可不带协议；[port] 默认 5005；[shareName] 为极空间里的共享名。
  static SyncConfig buildConfig({
    required String host,
    required String username,
    required String password,
    String shareName = '壹ZHANG核',
    int port = 5005,
    bool https = true,
  }) {
    var h = host.trim();
    h = h.replaceFirst(RegExp(r'^https?://'), '');
    h = h.split('/').first; // 去掉可能的路径尾巴
    final scheme = https ? 'https' : 'http';
    final base = '$scheme://$h:$port';
    final remoteBase = '/dav/$shareName';
    return SyncConfig(
      host: base,
      username: username,
      password: password,
      remoteBasePath: remoteBase,
      trustSelfSigned: https, // 极空间自签证书
      displayName: '极空间($h)',
    );
  }

  /// 用 [SyncConfig] 建立客户端并探测连通性。
  static Future<WebDavClient> connect(SyncConfig cfg) async {
    final client = WebDavClient(
      host: cfg.host,
      username: cfg.username,
      password: cfg.password,
      trustSelfSigned: cfg.trustSelfSigned,
      useDigest: true,
    );
    await client.testConnection(cfg.remoteBasePath);
    return client;
  }

  /// 远端「某文件」的完整路径（base + 规范化后的相对路径）。
  static String remotePath(SyncConfig cfg, String relativePath) {
    final base = cfg.remoteBasePath.endsWith('/')
        ? cfg.remoteBasePath.substring(0, cfg.remoteBasePath.length - 1)
        : cfg.remoteBasePath;
    return '$base/$relativePath';
  }
}
