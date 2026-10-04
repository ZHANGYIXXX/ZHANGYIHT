import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'logic/theme.dart';
import 'logic/seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 读本地主题偏好 → 写 Tokens → 作为 provider 初始值
  final saved = await loadTheme();
  applyTheme(saved);
  // 首次安装：把台账里已有的核桃先建好档（只跑一次）
  await Seed.runIfNeeded();
  runApp(
    ProviderScope(
      overrides: [themeProvider.overrideWith((ref) => saved)],
      child: const App(),
    ),
  );
}
