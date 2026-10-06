import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart' hide sha256;

/// WebDAV 通用客户端（PROPFIND / MKCOL / PUT / GET / DELETE / HEAD）。
/// PC 端与华为端共用同一实现，仅底层 http.Client 的证书策略不同。
///
/// 鉴权：默认 Basic；若 [useDigest]=true 且服务端返回 Digest 质询，
/// 则自动完成一次 Digest 握手（极空间 Z2PRO 多数固件要求 Digest）。
class WebDavClient {
  final String host; // https://host:port
  final String username;
  final String password;
  final bool trustSelfSigned;
  final bool useDigest;

  late final http.Client _client;

  // Digest 握手状态
  String? _realm, _nonce, _opaque, _qop;
  int _nc = 0;
  String _cnonce = '';

  WebDavClient({
    required this.host,
    required this.username,
    required this.password,
    this.trustSelfSigned = false,
    this.useDigest = false,
  }) {
    _client = trustSelfSigned
        ? IOClient(HttpClient()..badCertificateCallback = (_, __, ___) => true)
        : http.Client();
  }

  void dispose() => _client.close();

  String _join(String path) {
    final base = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  Map<String, String> _authHeaders(String method, String path) {
    if (!useDigest || _nonce == null) {
      final tok = base64.encode(utf8.encode('$username:$password'));
      return {'Authorization': 'Basic $tok'};
    }
    _nc++;
    _cnonce = _randomHex(8);
    final uri = path.startsWith('/') ? path : '/$path';
    final ha1 = _md5Hex('$username:$_realm:$password');
    final ha2 = _md5Hex('$method:$uri');
    final nc = _nc.toRadixString(16).padLeft(8, '0');
    final qop = _qop ?? 'auth';
    final resp = _md5Hex('$ha1:$_nonce:$nc:$_cnonce:$qop:$ha2');
    var auth = 'Digest username="$username", realm="$_realm", nonce="$_nonce", '
        'uri="$uri", response="$resp", algorithm=MD5, qop=$qop, nc=$nc, cnonce="$_cnonce"';
    if (_opaque != null) auth += ', opaque="$_opaque"';
    return {'Authorization': auth};
  }

  void _maybeParseDigest(http.BaseResponse resp) {
    final www = resp.headers['www-authenticate'] ?? resp.headers['WWW-Authenticate'];
    if (www == null || !www.toLowerCase().startsWith('digest')) return;
    final m = <String, String>{};
    final re = RegExp(r'(\w+)=(?:"([^"]*)"|([^,]*))');
    for (final mm in re.allMatches(www)) {
      m[(mm.group(1) ?? '').toLowerCase()] = (mm.group(2) ?? mm.group(3) ?? '').trim();
    }
    _realm = m['realm'];
    _nonce = m['nonce'];
    _opaque = m['opaque'];
    _qop = m['qop'];
  }

  /// 统一发送：401 → 重新解析 Digest 后重发一次；
  /// 修掉先前只有 propfind 有 401 重试、长备份 nonce 过期会中途失败的问题。
  Future<http.Response> _send(String method, String path,
      {Map<String, String>? extraHeaders, List<int>? bodyBytes}) async {
    Future<http.Response> doSend() async {
      final req = http.Request(method, Uri.parse(_join(path)))
        ..headers.addAll(_authHeaders(method, path))
        ..headers.addAll(extraHeaders ?? {});
      if (bodyBytes != null) req.bodyBytes = bodyBytes;
      final resp = await _client.send(req);
      return http.Response.fromStream(resp);
    }

    var r = await doSend();
    if (r.statusCode == 401 && useDigest) {
      _maybeParseDigest(r);
      r = await doSend();
    }
    return r;
  }

  /// 探测连通性与鉴权：对根目录做一次深度 1 的 PROPFIND。
  Future<void> testConnection(String rootPath) async {
    await propfind(rootPath, depth: 1);
  }

  Future<List<WebDavItem>> propfind(String path, {int depth = 1}) async {
    const body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:prop><d:resourcetype/><d:getcontentlength/>'
        '<d:getetag/><d:getlastmodified/></d:prop></d:propfind>';
    final r = await _send('PROPFIND', path,
        extraHeaders: {
          'Depth': '$depth',
          'Content-Type': 'application/xml; charset=utf-8',
        },
        bodyBytes: utf8.encode(body));
    if (r.statusCode >= 400) throw WebDavException(r.statusCode, r.body);
    return _parsePropfind(r.body);
  }

  /// 创建集合（目录）。
  Future<void> mkcol(String path) async {
    final r = await _send('MKCOL', path);
    if (r.statusCode >= 400 && r.statusCode != 405) {
      // 405 = 已存在，视为成功
      throw WebDavException(r.statusCode, r.body);
    }
  }

  /// 确保整条远端目录存在（逐级 MKCOL）。
  Future<void> mkcolRecursive(String path) async {
    final parts = path.split('/').where((e) => e.isNotEmpty).toList();
    var cur = '';
    for (final p in parts) {
      cur += '/$p';
      await mkcol(cur);
    }
  }

  /// 上传文件。
  /// [offset] > 0 时以断点续传方式追加（Content-Range）。
  /// [total] 为文件总字节数（用于 Content-Range 的结尾与总长度）。
  Future<void> put(
    String path,
    List<int> bytes, {
    int offset = 0,
    int? total,
  }) async {
    final all = total ?? (offset + bytes.length);
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
    };
    if (offset > 0) {
      final end = offset + bytes.length - 1;
      headers['Content-Range'] = 'bytes $offset-$end/$all';
    }
    final r = await _send('PUT', path, extraHeaders: headers, bodyBytes: bytes);
    if (r.statusCode >= 400) throw WebDavException(r.statusCode, r.body);
  }

  /// 下载文件。
  Future<List<int>> get(String path) async {
    final r = await _send('GET', path);
    if (r.statusCode >= 400) throw WebDavException(r.statusCode, r.body);
    return r.bodyBytes;
  }

  /// 删除文件或空目录。
  Future<void> delete(String path) async {
    final r = await _send('DELETE', path);
    if (r.statusCode >= 400) throw WebDavException(r.statusCode, r.body);
  }

  /// 远端已存在大小（用于断点续传前的探测）。不存在返回 -1。
  Future<int> headSize(String path) async {
    final r = await _send('HEAD', path);
    if (r.statusCode == 404) return -1;
    if (r.statusCode >= 400) throw WebDavException(r.statusCode, '');
    return int.tryParse(r.headers['content-length'] ?? '') ?? -1;
  }

  List<WebDavItem> _parsePropfind(String xml) {
    final items = <WebDavItem>[];
    final respRe = RegExp(r'<[^>]*response[^>]*>(.*?)</[^>]*response>',
        dotAll: true, caseSensitive: false);
    for (final rm in respRe.allMatches(xml)) {
      final block = rm.group(1) ?? '';
      final href = _tag(block, 'href');
      if (href == null) continue;
      final isCol = RegExp(r'<[^>]*collection[^>]*/?>', caseSensitive: false).hasMatch(block);
      final len = _tag(block, 'getcontentlength');
      final etag = _tag(block, 'getetag');
      final lm = _tag(block, 'getlastmodified');
      DateTime? modified;
      if (lm != null) {
        try {
          modified = HttpDate.parse(lm);
        } catch (_) {
          modified = null;
        }
      }
      items.add(WebDavItem(
        href: href,
        isCollection: isCol,
        contentLength: len == null ? null : int.tryParse(len),
        etag: etag,
        lastModified: modified,
      ));
    }
    return items;
  }

  static String? _tag(String block, String name) {
    final m = RegExp(r'<[^>]*$name[^>]*>(.*?)</[^>]*$name>',
        dotAll: true, caseSensitive: false).firstMatch(block);
    return m?.group(1)?.trim();
  }

  static String _md5Hex(String s) =>
      md5.convert(utf8.encode(s)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String _randomHex(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// PROPFIND 解析出的单项。
class WebDavItem {
  final String href;
  final bool isCollection;
  final int? contentLength;
  final String? etag;
  final DateTime? lastModified;
  const WebDavItem({
    required this.href,
    this.isCollection = false,
    this.contentLength,
    this.etag,
    this.lastModified,
  });
}

/// WebDAV 错误。
class WebDavException implements Exception {
  final int statusCode;
  final String body;
  WebDavException(this.statusCode, this.body);
  @override
  String toString() => 'WebDavException($statusCode): $body';
}
