import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/theme.dart';
import '../../data/database.dart';
import '../../logic/providers.dart';

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
        Text('把数据库和全部原图导出一份（原图按原始文件复制，不压缩）。重装 App 后用「导入」恢复，避免数据归零。',
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 12),
        GestureDetector(onTap: () => _export(context), child: NeumorphicBox(state: NeuState.raised, radius: Tokens.rBtn,
            padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: Text('导出数据库 + 原图', style: TextStyle(color: Tokens.accent, fontWeight: FontWeight.w700))))),
        const SizedBox(height: 10),
        GestureDetector(onTap: () => _import(context, ref), child: NeumorphicBox(state: NeuState.inset, radius: Tokens.rBtn,
            padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: Text('导入数据库 + 原图（恢复备份）', style: TextStyle(color: Tokens.seal, fontWeight: FontWeight.w700))))),
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

  // ---- 导入（镜像导出的目录快照）----
  // 流程：选备份 → 确认 → 关 DB 句柄 → 自动备份当前数据 → 清空 yizhanghe → 拷回备份 → 刷新
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final root = await _backupRoot();
      if (root == null) { _toast(context, '没有找到备份目录'); return; }
      final backups = await _listBackups(root);
      if (backups.isEmpty) {
        _toast(context, '没有可用的备份，请先「导出数据库 + 原图」');
        return;
      }
      final chosen = backups.length == 1 ? backups.first : (await _pickBackup(context, backups));
      if (chosen == null) return;

      final ok = await _confirm(context,
          '恢复「${p.basename(chosen.path)}」将覆盖当前 App 内的全部数据（导入前会自动备份当前数据）。确定恢复？');
      if (!ok) return;

      // 1) 先关数据库句柄，避免覆盖文件时句柄失效
      await AppDatabase.close();
      // 2) 自动备份当前数据（防误覆盖，可回滚）
      final base = await getApplicationDocumentsDirectory();
      final cur = Directory(p.join(base.path, 'yizhanghe'));
      if (await cur.exists()) {
        final safe = Directory(p.join(root.path, '__导入前自动备份_${_stamp()}'));
        await _copyDir(cur, safe);
      }
      // 3) 清空当前 yizhanghe，再拷回备份（干净恢复，无残留旧图/旧行）
      if (await cur.exists()) await cur.delete(recursive: true);
      await _copyDir(chosen, cur);
      // 4) 重置单例并刷新列表
      ref.invalidate(walnutsProvider);
      ref.invalidate(itemsProvider);
      _toast(context, '已恢复：${p.basename(chosen.path)}\n建议重启 App 以彻底刷新界面');
    } catch (e) {
      _toast(context, '导入失败: $e');
    }
  }

  // 备份根目录：与导出写到同一处（外部存储优先，回退到文档目录）
  Future<Directory?> _backupRoot() async {
    final candidates = <Directory?>[
      await getExternalStorageDirectory(),
      await getApplicationDocumentsDirectory(),
    ];
    for (final d in candidates) {
      if (d == null) continue;
      final r = Directory(p.join(d.path, '壹ZHANG核备份'));
      if (await r.exists()) return r;
    }
    return null;
  }

  // 只认包含 app.db 的子目录（时间戳文件夹），按字典序≈时间序排列
  Future<List<Directory>> _listBackups(Directory root) async {
    final out = <Directory>[];
    await for (final e in root.list()) {
      if (e is Directory && await File(p.join(e.path, 'app.db')).exists()) out.add(e as Directory);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  Future<Directory?> _pickBackup(BuildContext context, List<Directory> backups) => showDialog<Directory>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择要恢复的备份'),
          children: [
            for (final b in backups)
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(p.basename(b.path))),
          ],
        ),
      );

  Future<bool> _confirm(BuildContext context, String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定恢复')),
          ],
        ),
      ) ?? false;

  String _stamp() {
    final ts = DateTime.now();
    return '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-'
        '${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}';
  }

  void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
