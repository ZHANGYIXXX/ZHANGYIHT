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
/// ## 签名算法（严格按官方文档「请求签名」实现）
///
/// 1. `KeyTime` = `起始时间戳;过期时间戳`
/// 2. `SignKey` = **hex 小写**(HMAC-SHA1(SecretKey, KeyTime))——注意是十六进制，不是 Base64
/// 3. `HttpString` = `小写方法\n路径\nURL参数\n请求头\n`（空字段也要保留换行，故末尾必须有 `\n`）
/// 4. `StringToSign` = `sha1\n$KeyTime\n` + **hex 小写 SHA1(HttpString)** + `\n`
/// 5. `Signature` = **hex 小写**(HMAC-SHA1(SignKey, StringToSign))——同样不是 Base64
/// 6. 以查询参数形式附加到请求上（官方允许 Header 或 URL 两种，此处用 URL）
///
/// 已用官方文档实测样例校验：`SHA1(HttpString)` 与官方期望值逐字符一致。
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
  ///
  /// [query] 为参与签名的业务查询参数（如分片上传的 partNumber / uploadId）；
  /// 签名用的 `q-url-param-list` 只包含这些业务参数，不含 q-* 签名参数本身。
  ({Uri uri, Map<String, String> headers}) _signedRequest(
    String method,
    String key, {
    Map<String, String> query = const {},
    String? contentSha1Hex,
    Duration ttl = const Duration(minutes: 30),
  }) {
    final path = '/$key';

    // HttpString 里的 URL 参数段：key 转小写并按字典序排序；value 保持原样不编码
    // （已用官方文档「新增设备」实测样例校验：头部值不做 URLEncode）
    final queryKeys = query.keys.map((k) => k.toLowerCase()).toList()..sort();
    final httpParameters = queryKeys
        .map((k) {
          final orig = query.entries.firstWhere((e) => e.key.toLowerCase() == k);
          return '$k=${orig.value}';
        })
        .join('&');

    // HttpString 里的请求头段。
    // COS 官方要求 host 必须参与签名，否则服务端校验一定失败；
    // 若带 content-sha1 则一并签入。
    final signedHeaders = <String, String>{'host': cfg.host};
    if (contentSha1Hex != null) signedHeaders['x-cos-content-sha1'] = contentSha1Hex;
    final headerKeys = signedHeaders.keys.toList()..sort();
    final httpHeaders =
        headerKeys.map((k) => '${k.toLowerCase()}=${signedHeaders[k]}').join('&');
    final headerList = headerKeys.join(';');

    // HttpString = 小写方法 \n 路径 \n URL参数 \n 请求头 \n
    // 注意：仅方法转小写，**路径保留原始大小写**（官方案例 getUserResources 即为证）
    // 空字段也要保留换行，因此末尾的 \n 不能省
    final httpString =
        '${method.toLowerCase()}\n$path\n$httpParameters\n$httpHeaders\n';

    final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final keyTime = '$start;${start + ttl.inSeconds}';

    // SignKey 与Signature 均为十六进制小写（不是 Base64）
    final signKey = _hmacSha1Hex(cfg.secretKey, keyTime);
    final hashed = sha1.convert(utf8.encode(httpString)).toString();
    final stringToSign = 'sha1\n$keyTime\n$hashed\n';
    final signature = _hmacSha1Hex(signKey, stringToSign);

    final params = <String, String>{
      ...query, // 业务参数原样带上（Uri 会做编码）
      'q-sign-algorithm': 'sha1',
      'q-ak': cfg.secretId,
      'q-key-time': keyTime,
      'q-sign-time': keyTime,
      'q-header-list': headerList,
      'q-url-param-list': queryKeys.map((k) => k.toLowerCase()).join(';'),
      'q-signature': signature,
    };

    final headers = <String, String>{};
    if (contentSha1Hex != null) {
      headers['x-cos-content-sha1'] = contentSha1Hex;
    }
    return (
      uri: Uri.parse('https://${cfg.host}$path').replace(queryParameters: params),
      headers: headers,
    );
  }

  /// HMAC-SHA1 摘要，输出十六进制小写（官方规范要求，不能用 Base64）。
  static String _hmacSha1Hex(String key, String data) {
    final hmac = Hmac(sha1, utf8.encode(key));
    return hmac.convert(utf8.encode(data)).toString();
  }

  /// 从 COS 返回的 XML 错误体中提取 Code 与 Message。
  static ({String code, String message}) _parseCosError(String body) {
    final code = RegExp(r'<Code>(.*?)</Code>', dotAll: true).firstMatch(body)?.group(1) ?? '';
    final msg = RegExp(r'<Message>(.*?)</Message>', dotAll: true).firstMatch(body)?.group(1) ?? '';
    return (code: code.trim(), message: msg.trim());
  }

  /// 依据腾讯云错误码给出可读的中文说明。
  static String _explain(String code, String fallback) {
    switch (code) {
      case 'SignatureDoesNotMatch':
        return '签名不匹配。SecretId/SecretKey 填错或填反了（SecretKey 只显示一次，'
            '不要带引号和空格）；也可能是设备时间偏差过大。';
      case 'AccessDenied':
        return '密钥有效但没有该存储桶的权限。确认用的是主账号密钥，'
            '或子账号已获得 COS 相关权限。';
      case 'NoSuchBucket':
        return '存储桶不存在。桶名必须与控制台完全一致，且含末尾账号数字，'
            '例如 yizhanghe-1250000000。';
      case 'InvalidArgument':
        return '请求参数被腾讯云判为非法。常见是桶名或地域填错。';
      case 'RequestTimeTooSkewed':
        return '设备时间与服务器相差过大。请把手机时间设为「自动」。';
      default:
        return fallback;
    }
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
      // HEAD 响应没有 body，改用同签名的 GET 再取一次，便于拿到腾讯云的错误码
      final probe = _signedRequest('GET', '');
      final probeResp = await _http.get(probe.uri, headers: probe.headers);
      final err = _parseCosError(probeResp.body);
      final reason = _explain(err.code, 'HTTP ${resp.statusCode}${err.code.isEmpty ? '' : '（${err.code}）'}');
      throw StateError(reason);
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

    if (length <= _partSize) {
      final req = _signedRequest('PUT', key, contentSha1Hex: sha1.convert(bytes).toString());
      final resp = await _http.put(
        req.uri,
        headers: {...req.headers, 'Content-Length': '$length'},
        body: bytes,
      );
      if (resp.statusCode != 200) {
        final err = _parseCosError(resp.body);
        throw HttpException('上传 $key 失败：${_explain(err.code, 'HTTP ${resp.statusCode}')}');
      }
      return;
    }

    // 大文件：初始化分片上传 → 逐片 PUT → 完成合并
    final initReq = _signedRequest('POST', key, query: {'uploads': ''});
    final initResp = await _http.post(initReq.uri, headers: initReq.headers);
    if (initResp.statusCode != 200) {
      final err = _parseCosError(initResp.body);
      throw HttpException('初始化分片失败：${_explain(err.code, 'HTTP ${initResp.statusCode}')}');
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
        contentSha1Hex: sha1.convert(chunk).toString(),
      );
      final partResp = await _http.put(
        partReq.uri,
        headers: {
          ...partReq.headers,
          'Content-Length': '${chunk.length}',
        },
        body: chunk,
      );
      if (partResp.statusCode != 200) {
        final err = _parseCosError(partResp.body);
        throw HttpException(
            '分片 $part 上传失败：${_explain(err.code, 'HTTP ${partResp.statusCode}')}');
      }
    }

    final doneReq = _signedRequest(
      'POST',
      key,
      query: {'uploadId': uploadId},
    );
    final doneResp = await _http.post(doneReq.uri, headers: doneReq.headers);
    if (doneResp.statusCode != 200) {
      final err = _parseCosError(doneResp.body);
      throw HttpException('合并分片失败：${_explain(err.code, 'HTTP ${doneResp.statusCode}')}');
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