import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'logic/theme.dart';
import 'logic/seed.dart';

Future<void> main() async {
  // 全局异常兜底：把未捕获的 Dart 异常显示在界面上（而不是静默闪退），便于定位问题。
  FlutterError.onError = (details) => FlutterError.presentError(details);
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // 读本地主题偏好 → 写 Tokens → 作为 provider 初始值
    final saved = await loadTheme();
    applyTheme(saved);
    // 首次安装：把台账里已有的核桃先建好档（只跑一次）
    // V2：Windows 上 AppDatabase._init 内部会自动切换 sqflite_ffi 工厂，无需额外引导
    await Seed.runIfNeeded();
    runApp(
      ProviderScope(
        overrides: [themeProvider.overrideWith((ref) => saved)],
        child: const App(),
      ),
    );
  }, (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
}
