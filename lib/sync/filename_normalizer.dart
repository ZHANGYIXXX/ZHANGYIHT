/// 文件名规范化层。
///
/// 不同系统（Windows / 华为 / 极空间 Z2PRO 的 WebDAV 实现）对文件名非法字符、
/// 长度上限、大小写敏感度的容忍度不同。本层把任意「本地文件名 / 相对路径」
/// 统一映射为 WebDAV 安全的规范化相对路径（始终用 `/` 分隔），保证三端索引一致、
/// 不会出现远端拒绝写入或同名冲突。
class FilenameNormalizer {
  /// Windows / WebDAV 常见非法字符（含路径分隔符）
  static const String _illegal = r'<>:"/\|?*';

  /// 把单个基本文件名规范化为安全名（不含路径分隔）。
  static String normalize(String name) {
    // 1) 去掉任何路径分隔，只保留最后一段
    name = name.split(RegExp(r'[/\\]')).last;
    // 2) 非法字符 / 控制字符 -> 下划线
    final buf = StringBuffer();
    for (final r in name.runes) {
      final ch = String.fromCharCode(r);
      if (_illegal.contains(ch) || r < 0x20) {
        buf.write('_');
      } else {
        buf.write(ch);
      }
    }
    var s = buf.toString();
    // 3) 去掉首尾空格与首尾点（避免 "." / ".." / 尾点这类危险名）
    s = s.trim();
    while (s.startsWith('.')) {
      s = s.substring(1);
    }
    while (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    s = s.trim();
    if (s.isEmpty) s = 'file';
    // 4) 长度上限（极空间路径有上限，取 128 的安全值，保留扩展名）
    if (s.length > 128) {
      final dot = s.lastIndexOf('.');
      if (dot > 0 && dot < 128 - 1) {
        final ext = s.substring(dot);
        s = s.substring(0, 128 - ext.length) + ext;
      } else {
        s = s.substring(0, 128);
      }
    }
    return s;
  }

  /// 把本地相对路径（可能含平台分隔符）规范为 WebDAV 用的 `/` 分隔路径，逐段规范化。
  /// 处理 `.` 与 `..`，保证结果稳定可复现。
  static String normalizeRelative(String relativePath) {
    final parts = relativePath.split(RegExp(r'[/\\]'));
    final out = <String>[];
    for (final p in parts) {
      if (p.isEmpty || p == '.') continue;
      if (p == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(normalize(p));
    }
    return out.join('/');
  }
}
