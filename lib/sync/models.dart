// ignore_for_file: dangling_library_doc_comments
/// V2 同步模块共用数据模型。
/// PC 端（Flutter desktop）与华为端（Flutter Android）复用同一套类型，
/// 保证三端同步语义一致、索引可互认。

/// 同步目标配置（WebDAV 通用 + 极空间适配共用）。
class SyncConfig {
  /// 服务端地址，含协议与端口，例如 https://192.168.1.10:5005
  final String host;

  /// 登录用户名
  final String username;

  /// 登录密码（明文保存于本机私有存储；详见 config_store.dart 的安全说明）
  final String password;

  /// 远端根目录（规范化后的绝对路径），例如 /dav/壹ZHANG核
  final String remoteBasePath;

  /// 极空间常使用自签证书，开启后可跳过证书校验（仅内网可信环境使用）
  final bool trustSelfSigned;

  /// 给用户看的好记名称，如「家里极空间」
  final String? displayName;

  const SyncConfig({
    required this.host,
    required this.username,
    required this.password,
    required this.remoteBasePath,
    this.trustSelfSigned = false,
    this.displayName,
  });

  SyncConfig copyWith({
    String? host,
    String? username,
    String? password,
    String? remoteBasePath,
    bool? trustSelfSigned,
    String? displayName,
  }) {
    return SyncConfig(
      host: host ?? this.host,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteBasePath: remoteBasePath ?? this.remoteBasePath,
      trustSelfSigned: trustSelfSigned ?? this.trustSelfSigned,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'username': username,
        'password': password,
        'remoteBasePath': remoteBasePath,
        'trustSelfSigned': trustSelfSigned,
        'displayName': displayName,
      };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
        host: json['host'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        remoteBasePath: json['remoteBasePath'] as String,
        trustSelfSigned: json['trustSelfSigned'] as bool? ?? false,
        displayName: json['displayName'] as String?,
      );
}

/// 单个待同步文件的索引条目。
class SyncFileEntry {
  /// 规范化后的相对路径（统一用 / 分隔，已剔除非法字符）
  final String relativePath;

  /// 文件内容 SHA-256（小写十六进制）
  final String sha256;

  /// 字节大小
  final int size;

  /// 最后修改时间（毫秒时间戳）
  final int mtime;

  const SyncFileEntry({
    required this.relativePath,
    required this.sha256,
    required this.size,
    required this.mtime,
  });

  SyncFileEntry copyWith({
    String? relativePath,
    String? sha256,
    int? size,
    int? mtime,
  }) {
    return SyncFileEntry(
      relativePath: relativePath ?? this.relativePath,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': relativePath,
        'h': sha256,
        's': size,
        'm': mtime,
      };

  factory SyncFileEntry.fromJson(Map<String, dynamic> json) => SyncFileEntry(
        relativePath: json['p'] as String,
        sha256: json['h'] as String,
        size: json['s'] as int,
        mtime: json['m'] as int,
      );
}

/// 同步方向。
enum SyncDirection { upload, download, both }

/// 单次同步的汇总结果。
class SyncResult {
  final int uploaded;
  final int downloaded;
  final int skipped;
  final int failed;
  final List<String> errors;

  const SyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.errors = const [],
  });

  SyncResult operator +(SyncResult other) => SyncResult(
        uploaded: uploaded + other.uploaded,
        downloaded: downloaded + other.downloaded,
        skipped: skipped + other.skipped,
        failed: failed + other.failed,
        errors: [...errors, ...other.errors],
      );

  int get total => uploaded + downloaded + skipped + failed;

  @override
  String toString() =>
      'SyncResult(upload=$uploaded, download=$downloaded, skip=$skipped, fail=$failed)';
}
