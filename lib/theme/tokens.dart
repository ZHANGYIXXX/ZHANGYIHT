import 'package:flutter/material.dart';

// 设计令牌（支持主题切换：颜色/阴影/字体为运行时可变，由 logic/theme.dart 的 applyTheme 赋值）
// 说明：字号 / 圆角 / 数字字体 不随主题变化，保持 const。
class Tokens {
  // ---- 颜色（默认 = 新拟态冷灰；切瑞鹤图时被覆盖）----
  static Color bg = const Color(0xFFE3E8EF); // 屏幕/卡片/控件统一底
  static Color text = const Color(0xFF45506A); // 正文主色
  static Color muted = const Color(0xFF7E8BA3); // 次要文字
  static Color faint = const Color(0xFFA7B2C4); // 占位/最弱
  static Color accent = const Color(0xFF51618A); // 强调
  static Color accentSoft = const Color(0xFFD7DEEA); // 强调浅色（药丸/选中底）
  static Color ph1 = const Color(0xFFDDE3EC); // 图片占位亮端
  static Color ph2 = const Color(0xFFCCD5E2); // 图片占位暗端

  // 详情卡「深 10%」令牌
  static Color textD10 = const Color(0xFF3E485F);
  static Color mutedD10 = const Color(0xFF717D93);
  static Color goodD10 = const Color(0xFF366E51); // 全品绿
  static Color badD10 = const Color(0xFFA66847); // 有修/黄
  static Color accentD10 = const Color(0xFF49577C);

  // 主题扩展色（瑞鹤图用；新拟态下同系，保证旧引用不炸）
  static Color seal = const Color(0xFFA66847); // 朱砂：价格/重点/选中
  static Color sky = const Color(0xFFE3E8EF); // 顶部天空
  static Color gold = const Color(0xFFBFAF8F); // 淡金辅助线

  // ---- 阴影色 ----
  static Color lightShadow = const Color(0xEBFFFFFF);
  static Color darkShadow = const Color(0xC794A3BC);

  // ---- 字号 ----
  static const double fsLabel = 10;
  static const double fsHint = 12;
  static const double fsBody = 15;
  static const double fsEmph = 20;
  static const double fsInput = 17; // 表单输入文字（比正文大一档，键盘上更易读）

  // ---- 圆角 ----
  static const double rCard = 20;
  static const double rInput = 12;
  static const double rBtn = 12;
  static const double rPill = 999;

  // ---- 字体 ----
  static String fontCn = 'Microsoft YaHei';
  static const List<String> fontCnFallback = ['PingFang SC', 'Segoe UI', 'sans-serif'];
  static const String fontNum = 'Times New Roman';

  static const TextStyle numStyle = TextStyle(
    fontFamily: fontNum,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ---- 投影（引用可变颜色，故不能用 const）----
  static List<BoxShadow> out = const [
    BoxShadow(offset: Offset(-8, -8), blurRadius: 18, color: Color(0xEBFFFFFF)),
    BoxShadow(offset: Offset(8, 8), blurRadius: 22, color: Color(0xC794A3BC)),
  ];
  static List<BoxShadow> outSm = const [
    BoxShadow(offset: Offset(-5, -5), blurRadius: 10, color: Color(0xEBFFFFFF)),
    BoxShadow(offset: Offset(5, 5), blurRadius: 12, color: Color(0xC794A3BC)),
  ];
  // 凹陷：Flutter BoxShadow 无 inset，用反向配色模拟（视觉等效 CSS inset）
  static List<BoxShadow> inShadow = const [
    BoxShadow(offset: Offset(-5, -5), blurRadius: 10, color: Color(0xC794A3BC)),
    BoxShadow(offset: Offset(5, 5), blurRadius: 12, color: Color(0xEBFFFFFF)),
  ];
  static List<BoxShadow> inSm = const [
    BoxShadow(offset: Offset(-4, -4), blurRadius: 8, color: Color(0xC794A3BC)),
    BoxShadow(offset: Offset(4, 4), blurRadius: 10, color: Color(0xEBFFFFFF)),
  ];
}
