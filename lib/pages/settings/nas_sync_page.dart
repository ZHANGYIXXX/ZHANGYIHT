import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/platform_paths.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../sync/models.dart';
import '../../sync/config_store.dart';
import '../../sync/zspace_adapter.dart';
import '../../sync/orchestrator.dart';

/// NAS 同步（极空间 Z2PRO）设置页：配置向导 + 立即备份 + 校验。
class NasSyncPage extends ConsumerStatefulWidget {
  const NasSyncPage({super.key});
  @override
  ConsumerState<NasSyncPage> createState() => _NasSyncPageState();
}

class _NasSyncPageState extends ConsumerState<NasSyncPage> {
  final _host = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _share = TextEditingController(text: '壹ZHANG核');

  bool _testing = false;
  bool _syncing = false;
  String? _lastResult;

  @override
  void dispose() {
    _host.dispose(); _user.dispose(); _pass.dispose(); _share.dispose();
    super.dispose();
  }

  Future<SyncConfig?>? _savedCfgFuture;

  @override
  Widget build(BuildContext context) {
    _savedCfgFuture ??= SyncConfigStore.load();
    return Scaffold(
      backgroundColor: Tokens.bg,
      appBar: AppBar(
        backgroundColor: Tokens.bg,
        elevation: 0,
        title: Text('NAS 同步', style: TextStyle(color: Tokens.text, fontSize: Tokens.fsEmph)),
        iconTheme: IconThemeData(color: Tokens.text),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _intro(),
          const SizedBox(height: 16),
          FutureBuilder<SyncConfig?>(
            future: _savedCfgFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final cfg = snap.data;
              if (cfg != null) _fillForm(cfg);
              return Column(children: [
                _configBlock(cfg),
                const SizedBox(height: 16),
                if (cfg != null) ...[
                  _syncBlock(),
                  const SizedBox(height: 16),
                ],
              ]);
            },
          ),
          _statusLine(),
        ]),
      ),
    );
  }

  Widget _intro() => Text(
        '把收藏数据（数据库 + 全部原图）单向备份到极空间 Z2PRO。本地优先、原图原文件、不压缩。',
        style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint),
      );

  // ---- 配置块 ----
  Widget _configBlock(SyncConfig? cfg) => _block('NAS 配置${cfg != null ? '（已连接）' : ''}', [
        _field(_host, 'NAS 地址（IP 或域名）', keyboard: TextInputType.url),
        const SizedBox(height: 10),
        _field(_user, '用户名'),
        const SizedBox(height: 10),
        _field(_pass, '密码', obscure: true),
        const SizedBox(height: 10),
        _field(_share, 'WebDAV 共享目录名', hint: '壹ZHANG核'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _btn('测试连接', _testing, () => _testConnect(), accent: false)),
          const SizedBox(width: 10),
          Expanded(child: _btn(cfg != null ? '保存配置' : '保存并启用', false, () => _save())),
        ]),
      ]);

  // ---- 同步块 ----
  Widget _syncBlock() => _block('立即备份', [
        Text('扫描本地全部数据并上传到 NAS。已上传且未变化的文件会自动跳过。',
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 12),
        _btn('开始备份到 NAS', _syncing, () => _runSync(), accent: true),
        const SizedBox(height: 10),
        _btn('校验远端完整性', false, () => _verify(), accent: false),
      ]);

  Widget _statusLine() => _lastResult == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_lastResult!, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        );

  // ---- 组件 ----
  Widget _block(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint, fontWeight: FontWeight.w700))),
        NeumorphicBox(radius: Tokens.rCard, padding: const EdgeInsets.all(16), child: Column(children: children)),
      ]);

  Widget _field(TextEditingController c, String label, {bool obscure = false, TextInputType? keyboard, String? hint}) =>
      NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboard,
          style: TextStyle(color: Tokens.text, fontSize: Tokens.fsBody),
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            labelStyle: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint),
            hintStyle: TextStyle(color: Tokens.faint),
          ),
        ),
      );

  Widget _btn(String label, bool busy, VoidCallback onTap, {bool accent = false}) => GestureDetector(
        onTap: busy ? null : onTap,
        child: NeumorphicBox(
          state: busy ? NeuState.inset : NeuState.raised,
          radius: Tokens.rBtn,
          color: accent ? Tokens.accentSoft : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: busy
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Tokens.accent, strokeWidth: 2))
                : Text(label, style: TextStyle(color: accent ? Tokens.seal : Tokens.accent, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  // ---- 逻辑 ----
  void _fillForm(SyncConfig cfg) {
    if (_host.text.isEmpty) {
      // 从保存的 host 提取纯 IP（去掉 scheme:port）
      final ip = cfg.host.replaceFirst(RegExp(r'^https?://'), '').split(':').first;
      _host.text = ip;
      _user.text = cfg.username;
      _pass.text = cfg.password;
      if (cfg.remoteBasePath.split('/').length >= 3) _share.text = cfg.remoteBasePath.split('/').last;
    }
  }

  Future<void> _testConnect() async {
    setState(() => _testing = true);
    try {
      final cfg = ZSpaceAdapter.buildConfig(
        host: _host.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        shareName: _share.text.trim().isEmpty ? '壹ZHANG核' : _share.text.trim(),
      );
      await ZSpaceAdapter.connect(cfg);
      _toast('连接成功');
    } catch (e) {
      _toast('连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final cfg = ZSpaceAdapter.buildConfig(
      host: _host.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      shareName: _share.text.trim().isEmpty ? '壹ZHANG核' : _share.text.trim(),
    );
    await SyncConfigStore.save(cfg);
    setState(() => _savedCfgFuture = Future.value(cfg));
    _toast('配置已保存');
  }

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    try {
      final root = await PlatformPaths.appDataDir();
      final orch = SyncOrchestrator(onProgress: (done, total, f) {
        if (mounted && (done % 10 == 0 || done == total - 1)) {
          setState(() => _lastResult = '进度：$done / $total（$f）');
        }
      });
      final r = await orch.backupAll(root);
      _toast('备份完成：上传 ${r.uploaded}，跳过 ${r.skipped}，失败 ${r.failed}');
      if (r.errors.isNotEmpty) {
        setState(() => _lastResult = '失败明细：\n' + r.errors.take(5).join('\n'));
      }
    } catch (e) {
      _toast('备份失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _verify() async {
    try {
      final root = await PlatformPaths.appDataDir();
      final ok = await SyncOrchestrator().verifyRemoteSizes(root);
      _toast(ok ? '远端完整性校验通过' : '发现不一致，建议重新备份');
    } catch (e) {
      _toast('校验失败：$e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
