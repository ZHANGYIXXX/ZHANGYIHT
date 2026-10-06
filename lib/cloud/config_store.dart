import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 云同步配置持久化（shared_preferences）。
///
/// ⚠️ 安全说明：腾讯云 SecretKey 以明文保存在 shared_preferences。
/// shared_preferences 在 Android 上落在应用私有目录（其它App 无法读取），
/// 但**不是**加密存储。若后续要提高安全等级，应改用 flutter_secure_storage
/// （需新增依赖）。当前为避免引入新包而沿用既有做法，与删除前的
/// lib/sync/config_store.dart 保持同一安全等级。
class SyncConfigStore {
  static const _k = 'yizhanghe_cloud_sync_config_v1';

  static Future<SyncConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw == null || raw.isEmpty) return null;
    try {
      final cfg = SyncConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return cfg.isValid ? cfg : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SyncConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k, jsonEncode(cfg.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k);
  }
}