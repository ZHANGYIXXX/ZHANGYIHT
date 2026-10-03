import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/tokens.dart';
import 'pages/shell/app_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '壹ZHANG核',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Tokens.bg,
        fontFamily: Tokens.fontCn,
        fontFamilyFallback: Tokens.fontCnFallback,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Tokens.text, fontSize: Tokens.fsBody),
        ),
        colorScheme: ColorScheme.light(
          primary: Tokens.accent,
          background: Tokens.bg,
          surface: Tokens.bg,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
