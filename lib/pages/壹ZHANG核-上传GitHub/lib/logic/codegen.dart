import '../data/models/enums.dart';

// 编号生成器
// 格式：品类缩写 + YYYYMMDD + -重名序
// 例：2025-04-11 第 1 个核桃 → HZ250411-1
// 品种名不进编号（拍板结论），中文展示即可
class CodeGen {
  /// maxSeq = 该类型 + 该日期下「已存在编号中的最大序号」。
  /// 早前传的是「已有条数」，删掉中间一条后会算出重复号（如 -2 用了两次），
  /// 故改为取现有编号最大值 +1。
  static String format(String type, String buyDate, int maxSeq) {
    final abbr = typeAbbr[type] ?? 'OT';
    final ymd = buyDate.replaceAll('-', '');
    return '$abbr$ymd-${maxSeq + 1}';
  }

  /// 从一批已存在的编号里解析出最大序号（没有有效序号返回 0）
  static int maxSeq(Iterable<String> codes) {
    var max = 0;
    for (final c in codes) {
      final i = c.lastIndexOf('-');
      if (i < 0) continue;
      final n = int.tryParse(c.substring(i + 1).trim());
      if (n != null && n > max) max = n;
    }
    return max;
  }
}
