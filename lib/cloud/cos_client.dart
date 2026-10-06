import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// 腾讯云 COS 轻量客户端（纯 Dart 实现，不依赖官方插件）。
///
/// 为什么不引官方 `tencentcloud_cos_sdk_plugin`：该插件仅支持
/// iOS / Android / 鸿蒙，**不支持 Windows**，而本项目需要 PC 与手机双端。
/// COS 的 REST 接口 + 签名算法是公开规范，用现有 http + crypto 即可实现，
/// 跨平台通吃，且不新增任何依赖。
///
/// 签名算法（腾讯云官方文档「签名方法 v5」中简化版的 COS XML API 风格）：
///   1. 构造 HttpString：method\nlowercase(uri path)\n\n\n\n\n\n
///   2. SignatureTime 为 keyTime = now;now+有效期
///   3. signKey = HMAC-SHA1(secretKey, keyTime)
///   4. stringToSign = "sha1\n$keyTime\n$signKey\n$httpString"
///   5. signature = Base64(HMAC-SHA1(signKey, stringToSign))
///   6. Authorization: q-sign-algorithm=sha1&q-ak=..&q-sign-time=..&q-key-time=..&q-header-list=&q-url-param-list=&q-signature=..
class CosClient {
  final SyncConfig cfg;

  /// 上传分片大小（8MB，COS 单次 PUT 推荐不超过 1GB，这里保守分片便于失败重试）
  static const int _partSize = 8 * 1024 * 1024;

  final http.Client _http = http.Client();

  CosClient(this.cfg);

  void dispose() => _http.close();

  /// 对外暴露对象 key 构造（远端完整 key = <remoteBasePath>/<relativePath>）
  String objectKey(String relativePath) {
    final base = cfg.remoteBasePath.replaceAll(RegExp(r'^/+|/+$'), '');
    final rel = relativePath.replaceAll(RegExp(r'^/+'), '');
    return base.isEmpty ? rel : '$base/$rel';
  }

  /// 构造带签名的请求 URI与 Authorization 头。
  ({Uri uri, Map<String, String> headers}) _signedRequest(
    String method,
    String key, {
    Map<String, String> query = const {},
    String? payloadSha256,
    Duration ttl = const Duration(minutes: 30),
  }) {
    final path = '/$key';
    final params = <String, String>{
      'q-sign-algorithm': 'sha1',
      'q-ak': cfg.secretId,
    };
    // COS 的 q-url-param-list 需要按字典序、URL 编码后参与签名
    params.addAll(query);

    final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final end = start + ttl.inSeconds;
    final keyTime = '$start;$end';
    params['q-key-time'] = keyTime;
    params['q-sign-time'] = keyTime;

    final httpString = '$method\n${path.toLowerCase()}\n\n\n\n\n';
    final signKey = _hmacSha1Base64(cfg.secretKey, keyTime);
    final stringToSign = 'sha1\n$keyTime\n$signKey\n$httpString';
    final signature = _hmacSha1Base64(signKey, stringToSign);

    params['q-header-list'] = payloadSha256 == null ? '' : 'x-cos-content-sha1';
    // q-url-param-list 必须是参与签名的 query 键，按字典序以分号连接
    final signedKeys = query.keys.toList()..sort();
    params['q-url-param-list'] = signedKeys.join(';');
    params['q-signature'] = signature;

    final headers = <String, String>{};
    if (payloadSha256 != null) {
      headers['x-cos-content-sha1'] = payloadSha256;
    }
    return (
      uri: Uri.parse('https://${cfg.host}$path').replace(queryParameters: params),
      headers: headers,
    );
  }

  static String _hmacSha1Base64(String key, String data) {
    final hmac = Hmac(sha1, utf8.encode(key));
    return base64.encode(hmac.convert(utf8.encode(data)).bytes);
  }

  /// 连通性探测：HEAD 存储桶根，判断密钥与地域是否正确。
  /// 成功返回 true；失败抛 [StateError] 并带上可读原因。
  Future<bool> testConnection() async {
    // 前置校验：Bucket 名格式错会导致 TLS 握手直接失败，
    // 报出来的是 CERTIFICATE_VERIFY_FAILED / Hostname mismatch，
    // 与「密钥不对」完全无关，不预处理的话排查方向会被带偏。
    final bucket = cfg.bucket.trim();
    if (bucket.isEmpty) {
      throw StateError('存储桶名没填。请到腾讯云控制台「对象存储 → 存储桶列表」'
          '复制桶名，形如 yizhanghe-1250000000（必须带末尾那串账号数字）');
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*-\d+$').hasMatch(bucket)) {
      throw StateError('存储桶名格式不对：$bucket\n'
          '正确格式 = 你的桶名 + 短横线 + 账号数字，例：yizhanghe-1250000000。\n'
          '注意只能是英文小写字母、数字、短横线，不能用中文。');
    }

    final req = _signedRequest('HEAD', '');
    try {
      final resp = await _http.head(req.uri, headers: req.headers);
      if (resp.statusCode == 200) return true;
      if (resp.statusCode == 403) {
        throw StateError('存储桶找到了，但密钥或地域不对（403）。'
            '请检查 SecretId / SecretKey，以及地域是否与创建桶时一致');
      }
      if (resp.statusCode == 404) {
        throw StateError('存储桶不存在（404）。请确认桶名拼写完全一致，'
            '含末尾账号数字，且地域与桶实际所在地一致');
      }
      throw StateError('连接失败：HTTP ${resp.statusCode}');
    } on HandshakeException catch (e) {
      throw StateError('HTTPS 握手失败（${e.message}）。\n'
          '若桶名与地域确认无误，可能是当前网络对 COS 域名的拦截，'
          '请换手机卡/网络（如移动数据）后重试');
    }
  }

  /// 上传单个本地文件（分片 PUT，支持大图）。
  Future<void> uploadFile(File file, String key) async {
    final length = await file.length();
    final bytes = await file.readAsBytes();
    final payload = base64.encode(sha1Bytes(bytes));

    if (length <= _partSize) {
      final req = _signedRequest('PUT', key, payloadSha256: payload);
      final resp = await _http.put(
        req.uri,
        headers: {...req.headers, 'Content-Length': '$length'},
        body: bytes,
      );
      if (resp.statusCode != 200) {
        throw HttpException('上传 $key 失败：HTTP ${resp.statusCode} ${resp.body}');
      }
      return;
    }

    // 大文件：初始化分片上传 → 逐片 PUT → 完成合并
    final initReq = _signedRequest('POST', key, query: {'uploads': ''});
    final initResp = await _http.post(initReq.uri, headers: initReq.headers);
    if (initResp.statusCode != 200) {
      throw HttpException('初始化分片失败：HTTP ${initResp.statusCode} ${initResp.body}');
    }
    final uploadId = RegExp(r'<UploadId>(.*?)</UploadId>')
        .firstMatch(initResp.body)
        ?.group(1);
    if (uploadId == null || uploadId.isEmpty) {
      throw const HttpException('未能解析 UploadId');
    }

    var part = 1;
    for (var off = 0; off < length; off += _partSize, part++) {
      final end = (off + _partSize < length) ? off + _partSize : length;
      final chunk = bytes.sublist(off, end);
      final partReq = _signedRequest(
        'PUT',
        key,
        query: {
          'partNumber': '$part',
          'uploadId': uploadId,
        },
        payloadSha256: base64.encode(sha1Bytes(chunk)),
      );
      final partResp = await _http.put(
        partReq.uri,
        headers: {
          ...partReq.headers,
          'Content-Length': '${chunk.length}',
          // 签名需覆盖本片的 Content-Range
          'x-cos-content-range': 'bytes $off-${end - 1}/$length',
        },
        body: chunk,
      );
      if (partResp.statusCode != 200) {
        throw HttpException('分片 $part 上传失败：HTTP ${partResp.statusCode}');
      }
    }

    final doneReq = _signedRequest(
      'POST',
      key,
      query: {'uploadId': uploadId},
    );
    final doneResp = await _http.post(doneReq.uri, headers: doneReq.headers);
    if (doneResp.statusCode != 200) {
      throw HttpException('合并分片失败：HTTP ${doneResp.statusCode} ${doneResp.body}');
    }
  }

  /// 下载对象到本地文件。
  Future<void> downloadObject(String key, File dest) async {
    final req = _signedRequest('GET', key);
    final resp = await _http.get(req.uri, headers: req.headers);
    if (resp.statusCode != 200) {
      throw HttpException('下载 $key 失败：HTTP ${resp.statusCode}');
    }
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(resp.bodyBytes);
  }

  /// 查询对象大小；不存在返回 null。
  Future<int?> headSize(String key) async {
    try {
      final req = _signedRequest('HEAD', key);
      final resp = await _http.head(req.uri, headers: req.headers);
      if (resp.statusCode == 200) return int.parse(resp.headers['content-length'] ?? '-1');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// SHA-1 二进制摘要（COS 签名用，非完整性校验用）。
  static List<int> sha1Bytes(List<int> data) {
    final h = sha1.convert(data);
    return h.bytes;
  }
}