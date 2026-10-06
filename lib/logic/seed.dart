import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/daos/walnut_dao.dart';
import '../data/models/walnut.dart';
import 'codegen.dart';

/// 预置档案：把「核桃记录台账」里的既有核桃在首次启动时建好档，
/// 这样装上 App 就能逐条上传定妆照和走色图，不用先手工录 36 遍。
///
/// 只在「从未导入过」时执行一次（SharedPreferences 打标记），
/// 之后壹怎么删改都不会再灌回来。
class Seed {
  static const String _asset = 'assets/seed/walnuts.json';
  static const String _flag = 'seed_walnut_done';

  /// 返回本次导入的条数（已导入过返回 0）
  static Future<int> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flag) ?? false) return 0;

    int n = 0;
    try {
      final json = await rootBundle.loadString(_asset);
      final list = jsonDecode(json) as List<dynamic>;
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final buyDate = (m['buyDate'] as String? ?? '').trim();
        if (buyDate.isEmpty) continue; // 没有入手日期无法生成编号，跳过
        final seq = await WalnutDao.maxSeqSameDay(buyDate);
        final code = CodeGen.format('核桃', buyDate, seq);
        await WalnutDao.insert(Walnut(
          code: code,
          name: (m['name'] as String? ?? '').trim(),
          category: (m['category'] as String? ?? '').trim(),
          variety: (m['variety'] as String? ?? '').trim(),
          price: _d(m['price']),
          lBian: _d(m['lBian']),
          lDu: _d(m['lDu']),
          lGao: _d(m['lGao']),
          rBian: _d(m['rBian']),
          rDu: _d(m['rDu']),
          rGao: _d(m['rGao']),
          weight: _d(m['weight']),
          buyDate: buyDate,
          channel: (m['channel'] as String? ?? '').trim(),
          merchant: (m['merchant'] as String? ?? '').trim(),
          full: m['full'] == true,
          repaired: m['repaired'] == true,
          yellow: m['yellow'] == true,
        ));
        n++;
      }
    } catch (_) {
      // 资产缺失或格式异常不阻塞启动，下次再试
      return 0;
    }
    await prefs.setBool(_flag, true);
    return n;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
