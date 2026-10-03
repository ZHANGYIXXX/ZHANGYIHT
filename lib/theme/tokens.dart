import 'package:flutter/material.dart';

// 设计令牌（对应 需求文档/设计令牌.md · 新拟态冷灰）
// 颜色 / 字号 / 圆角 / 阴影 全部照原型落地，Flutter 阶段按此实现保证视觉一致。
class Tokens {
  // ---- 颜色（新拟态冷灰）----
  static const Color bg = Color(0xFFE3E8EF); // 屏幕/卡片/控件统一底
  static const Color text = Color(0xFF45506A); // 正文主色
  static const Color muted = Color(0xFF7E8BA3); // 次要文字
  static const Color faint = Color(0xFFA7B2C4); // 占位/最弱
  static const Color accent = Color(0xFF51618A); // 冷调强调
  static const Color accentSoft = Color(0xFFD7DEEA); // 强调浅色（药丸/选中底）
  static const Color ph1 = Color(0xFFDDE3EC); // 图片占位亮端
  static const Color ph2 = Color(0xFFCCD5E2); // 图片占位暗端

  // 详情卡「深 10%」令牌（第五轮）
  static const Color textD10 = Color(0xFF3E485F);
  static const Color mutedD10 = Color(0xFF717D93);
  static const Color goodD10 = Color(0xFF366E51); // 全品绿
  static const Color badD10 = Color(0xFFA66847); // 有修/黄
  static const Color accentD10 = Color(0xFF49577C);

  // ---- 阴影色 ----
  static const Color lightShadow = Color(0xEBFFFFFF); // rgba(255,255,255,.92)
  static const Color darkShadow = Color(0xC794A3BC); // rgba(148,163,188,.78)

  // ---- 字号四级 ----
  static const double fsLabel = 10; // 最小标签
  static const double fsHint = 12; // 辅助说明
  static const double fsBody = 15; // 正文·卡片
  static const double fsEmph = 20; // 强调

  // ---- 圆角 ----
  static const double rCard = 20;
  static const double rInput = 12;
  static const double rBtn = 12;
  static const double rPill = 999;

  // ---- 字体 ----
  static const String fontCn = 'Microsoft YaHei';
  static const List<String> fontCnFallback = ['PingFang SC', 'Segoe UI', 'sans-serif'];
  static const String fontNum = 'Times New Roman';

  // 数字样式（TNR + 等宽对齐）
  static const TextStyle numStyle = TextStyle(
    fontFamily: fontNum,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ---- 投影（新拟态 · 第八轮再加深 → 兼顾方案：blur 整体下调 20%）----
  // 凸起
  static const List<BoxShadow> out = [
    BoxShadow(offset: Offset(-8, -8), blurRadius: 18, color: lightShadow),
    BoxShadow(offset: Offset(8, 8), blurRadius: 22, color: darkShadow),
  ];
  // 小凸起
  static const List<BoxShadow> outSm = [
    BoxShadow(offset: Offset(-5, -5), blurRadius: 10, color: lightShadow),
    BoxShadow(offset: Offset(5, 5), blurRadius: 12, color: darkShadow),
  ];
  // 凹陷：Flutter BoxShadow 无 inset 属性，用反向配色模拟（视觉等效 CSS inset）
  static const List<BoxShadow> inShadow = [
    BoxShadow(offset: Offset(-5, -5), blurRadius: 10, color: darkShadow),
    BoxShadow(offset: Offset(5, 5), blurRadius: 12, color: lightShadow),
  ];
  // 小凹陷（按压/锁定）
  static const List<BoxShadow> inSm = [
    BoxShadow(offset: Offset(-4, -4), blurRadius: 8, color: darkShadow),
    BoxShadow(offset: Offset(4, 4), blurRadius: 10, color: lightShadow),
  ];
}
