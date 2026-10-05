import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// 同步配置存储。
///
/// 当前用 shared_preferences 明文保存（含密码）。V2 后续应迁移到
/// flutter_secure_storage（Android Keystore / Windows Credential Manager）以更安全。
/// 见 V2 清单 §1 配置层「失败降级 / 安全」一节。
class SyncConfigStore {
  static const _key = 'sync_config_v2';

  /// 读取已保存的配置；无则返回 null。
  static Future<SyncConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SyncConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 保存配置（覆盖写）。
  static Future<void> save(SyncConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cfg.toJson()));
  }

  /// 清除已保存配置（如用户退出 NAS 账号）。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
