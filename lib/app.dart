import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/tokens.dart';
import 'logic/theme.dart';
import 'pages/shell/app_shell.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题变化 → 先写 Tokens，再重建 MaterialApp，全局底色/强调色随之切换
    final key = ref.watch(themeProvider);
    applyTheme(key);
    return MaterialApp(
      title: 'ZHANGYIWW',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Tokens.bg,
        fontFamily: Tokens.fontCn,
        fontFamilyFallback: Tokens.fontCnFallback,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Tokens.text, fontSize: Tokens.fsBody),
        ),
        colorScheme: ColorScheme.light(
          primary: Tokens.accent,
          background: Tokens.bg,
          surface: Tokens.bg,
          error: Tokens.seal,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
