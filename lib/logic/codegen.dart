import '../data/models/enums.dart';

// 编号生成器
// 格式：品类缩写 + YYYYMMDD + -重名序
// 例：2025-04-11 第 1 个核桃 → HZ250411-1
// 品种名不进编号（拍板结论），中文展示即可
class CodeGen {
  static String format(String type, String buyDate, int sameDayCount) {
    final abbr = typeAbbr[type] ?? 'OT';
    final ymd = buyDate.replaceAll('-', '');
    return '$abbr$ymd-${sameDayCount + 1}';
  }
}
