import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/tokens.dart';

/// 主题：neu = 新拟态冷灰（原版）；crane = 《瑞鹤图》（壹确认的 V9 色卡）
enum ThemeKey { neu, crane }

const String _kTheme = 'theme_key';

/// 当前主题（启动时由 main 读取本地存储后 override 初始值）
final themeProvider = StateProvider<ThemeKey>((ref) => ThemeKey.neu);

/// 把主题色写入 Tokens（全局可变令牌），随后 MaterialApp 重建即可生效
void applyTheme(ThemeKey key) {
  if (key == ThemeKey.crane) {
    // ——《瑞鹤图》：壹指定色卡 ——
    Tokens.bg = const Color(0xFFF7F3E8); // 宣纸米白
    Tokens.text = const Color(0xFF333333); // 正文·深墨灰
    Tokens.muted = const Color(0xFF7A7A7A); // 弱化·浅灰墨
    Tokens.faint = const Color(0xFFA9A294); // 占位
    Tokens.accent = const Color(0xFF8FA3B7); // 宫阙青灰（结构强调）
    Tokens.accentSoft = const Color(0x248FA3B7); // 青灰淡底
    Tokens.ph1 = const Color(0xFFFBF8EF);
    Tokens.ph2 = const Color(0x1A8FA3B7);

    Tokens.textD10 = const Color(0xFF2B2B2B); // 标题
    Tokens.mutedD10 = const Color(0xFF6E6E6E);
    Tokens.goodD10 = const Color(0xFF4E7A5C); // 全品
    Tokens.badD10 = const Color(0xFFB5452F); // 有修/黄 → 朱砂
    Tokens.accentD10 = const Color(0xFF7E94AA);

    Tokens.seal = const Color(0xFFB5452F); // 朱砂：价格/重点/选中
    Tokens.sky = const Color(0xFFEAF1F6); // 淡青天空
    Tokens.gold = const Color(0xFFBFAF8F); // 淡金辅助线

    // 宣纸上的柔和投影（暖白高光 + 暖灰暗部）
    Tokens.lightShadow = const Color(0xE6FFFDF5);
    Tokens.darkShadow = const Color(0x99C9C0AC);

    Tokens.fontCn = '楷体_GB2312'; // 宋刻本气质（瘦金体无开源字库）
  } else {
    // ——新拟态冷灰（原版）——
    Tokens.bg = const Color(0xFFE3E8EF);
    Tokens.text = const Color(0xFF45506A);
    Tokens.muted = const Color(0xFF7E8BA3);
    Tokens.faint = const Color(0xFFA7B2C4);
    Tokens.accent = const Color(0xFF51618A);
    Tokens.accentSoft = const Color(0xFFD7DEEA);
    Tokens.ph1 = const Color(0xFFDDE3EC);
    Tokens.ph2 = const Color(0xFFCCD5E2);

    Tokens.textD10 = const Color(0xFF3E485F);
    Tokens.mutedD10 = const Color(0xFF717D93);
    Tokens.goodD10 = const Color(0xFF366E51);
    Tokens.badD10 = const Color(0xFFA66847);
    Tokens.accentD10 = const Color(0xFF49577C);

    Tokens.seal = const Color(0xFFA66847);
    Tokens.sky = const Color(0xFFE3E8EF);
    Tokens.gold = const Color(0xFFBFAF8F);

    Tokens.lightShadow = const Color(0xEBFFFFFF);
    Tokens.darkShadow = const Color(0xC794A3BC);

    Tokens.fontCn = 'Microsoft YaHei';
  }

  // 阴影列表依赖 lightShadow / darkShadow，需重建
  Tokens.out = [
    BoxShadow(offset: const Offset(-8, -8), blurRadius: 18, color: Tokens.lightShadow),
    BoxShadow(offset: const Offset(8, 8), blurRadius: 22, color: Tokens.darkShadow),
  ];
  Tokens.outSm = [
    BoxShadow(offset: const Offset(-5, -5), blurRadius: 10, color: Tokens.lightShadow),
    BoxShadow(offset: const Offset(5, 5), blurRadius: 12, color: Tokens.darkShadow),
  ];
  Tokens.inShadow = [
    BoxShadow(offset: const Offset(-5, -5), blurRadius: 10, color: Tokens.darkShadow),
    BoxShadow(offset: const Offset(5, 5), blurRadius: 12, color: Tokens.lightShadow),
  ];
  Tokens.inSm = [
    BoxShadow(offset: const Offset(-4, -4), blurRadius: 8, color: Tokens.darkShadow),
    BoxShadow(offset: const Offset(4, 4), blurRadius: 10, color: Tokens.lightShadow),
  ];
}

Future<ThemeKey> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final i = prefs.getInt(_kTheme);
  if (i == null || i < 0 || i >= ThemeKey.values.length) return ThemeKey.neu;
  return ThemeKey.values[i];
}

Future<void> saveTheme(ThemeKey key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kTheme, key.index);
}

/// 主题名（设置页展示）
String themeName(ThemeKey k) => k == ThemeKey.crane ? '瑞鹤图' : '新拟态';
