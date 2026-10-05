import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(backgroundColor: Tokens.bg, body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('设置', style: TextStyle(fontSize: Tokens.fsEmph, fontWeight: FontWeight.bold, color: Tokens.text)),
      const SizedBox(height: 16),
      _themeBlock(ref),
      const SizedBox(height: 16),
      _block('数据备份', [
        Text('把数据库和全部原图导出一份（原图按原始文件复制，不压缩）。导出完成后会提示具体存放路径。',
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 12),
        GestureDetector(onTap: () => _export(context), child: NeumorphicBox(state: NeuState.raised, radius: Tokens.rBtn,
            padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: Text('导出数据库 + 原图', style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700))))),
      ]),
      const SizedBox(height: 16),
      _block('关于', [
        _kv('App', 'ZHANGYIWW'),
        _kv('版本', 'V1.0.0'),
        _kv('用途', '文玩核桃收藏管理'),
      ]),
      const SizedBox(height: 16),
      Text('网页相册分享、NAS 同步为 V2 规划功能。', style: TextStyle(color: Tokens.faint, fontSize: Tokens.fsLabel)),
    ])));
  }

  Widget _block(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint, fontWeight: FontWeight.w700))),
    NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child: Column(children: children)),
  ]);

  // ---- 主题切换（CI 反馈 #3 / #4）----
  Widget _themeBlock(WidgetRef ref) {
    final cur = ref.watch(themeProvider);
    return _block('主题', [
      Text('切换全局配色与字体，选择后立即生效并记住。',
          style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
      const SizedBox(height: 12),
      Row(children: [
        for (final k in ThemeKey.values) ...[
          Expanded(child: _themeChip(ref, k, cur == k)),
          if (k != ThemeKey.values.last) const SizedBox(width: 10),
        ],
      ]),
    ]);
  }

  Widget _themeChip(WidgetRef ref, ThemeKey k, bool on) => GestureDetector(
        onTap: () {
          ref.read(themeProvider.notifier).state = k;
          saveTheme(k);
        },
        child: NeumorphicBox(
          state: on ? NeuState.raised : NeuState.inset,
          radius: Tokens.rBtn,
          color: on ? Tokens.accentSoft : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              themeName(k),
              style: TextStyle(
                fontSize: Tokens.fsBody,
                color: on ? Tokens.seal : Tokens.muted,
                fontWeight: on ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
    Text(k, style: TextStyle(color: Tokens.muted)),
    const Spacer(),
    Text(v, style: TextStyle(color: Tokens.text, fontWeight: FontWeight.w600)),
  ]));

  Future<void> _export(BuildContext context) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final src = Directory(p.join(base.path, 'yizhanghe'));
      if (!await src.exists()) { _toast(context, '还没有任何数据'); return; }
      final dl = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      final stamp = '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}';
      final dest = Directory(p.join(dl.path, '壹ZHANG核备份', stamp));
      await _copyDir(src, dest);
      final files = await dest.list(recursive: true).length;
      _toast(context, '已导出 $files 项到：\n${dest.path}');
    } catch (e) {
      _toast(context, '导出失败: $e');
    }
  }

  Future<void> _copyDir(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final e in src.list(recursive: false)) {
      final name = p.basename(e.path);
      if (e is Directory) {
        await _copyDir(e, Directory(p.join(dest.path, name)));
      } else {
        await (e as File).copy(p.join(dest.path, name));
      }
    }
  }

  void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
