// ignore_for_file: dangling_library_doc_comments
/// V2 云同步模块共用数据模型。
/// PC 端（Flutter desktop）与手机端（Flutter Android）复用同一套类型，
/// 保证两端同步语义一致、索引可互认。

/// 云同步目标配置（腾讯云 COS）。
class SyncConfig {
  /// 存储桶名称，形如 `yizhanghe-1250000000`（含 AppId 后缀）
  final String bucket;

  /// 地域，如 `ap-guangzhou`
  final String region;

  /// 腾讯云 API 密钥 ID
  final String secretId;

  /// 腾讯云 API 密钥
  final String secretKey;

  /// 远端根前缀（规范化后不含首尾斜杠），例如 `壹ZHANG核`
  final String remoteBasePath;

  /// 给用户看的好记名称，如「腾讯云」
  final String? displayName;

  const SyncConfig({
    required this.bucket,
    required this.region,
    required this.secretId,
    required this.secretKey,
    required this.remoteBasePath,
    this.displayName,
  });

  /// 存储桶所在的 COS 域名，如 `yizhanghe-1250000000.cos.ap-guangzhou.myqcloud.com`
  String get host => '$bucket.cos.$region.myqcloud.com';

  /// 配置是否填写完整（缺任一项都无法发起请求）
  bool get isValid =>
      bucket.isNotEmpty &&
      region.isNotEmpty &&
      secretId.isNotEmpty &&
      secretKey.isNotEmpty;

  SyncConfig copyWith({
    String? bucket,
    String? region,
    String? secretId,
    String? secretKey,
    String? remoteBasePath,
    String? displayName,
  }) {
    return SyncConfig(
      bucket: bucket ?? this.bucket,
      region: region ?? this.region,
      secretId: secretId ?? this.secretId,
      secretKey: secretKey ?? this.secretKey,
      remoteBasePath: remoteBasePath ?? this.remoteBasePath,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() => {
        'bucket': bucket,
        'region': region,
        'secretId': secretId,
        'secretKey': secretKey,
        'remoteBasePath': remoteBasePath,
        'displayName': displayName,
      };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
        bucket: json['bucket'] as String? ?? '',
        region: json['region'] as String? ?? '',
        secretId: json['secretId'] as String? ?? '',
        secretKey: json['secretKey'] as String? ?? '',
        remoteBasePath: json['remoteBasePath'] as String? ?? '壹ZHANG核',
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
