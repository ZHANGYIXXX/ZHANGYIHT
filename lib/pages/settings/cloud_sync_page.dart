import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/cos_client.dart';
import '../../cloud/config_store.dart';
import '../../cloud/models.dart';
import '../../cloud/orchestrator.dart';
import '../../logic/platform_paths.dart';
import '../../theme/nu.dart';
import '../../theme/tokens.dart';

/// 云同步（腾讯云 COS）设置页：配置向导 + 立即备份 + 校验。
class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});
  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage> {
  final _bucket = TextEditingController();
  final _region = TextEditingController(text: 'ap-guangzhou');
  final _secretId = TextEditingController();
  final _secretKey = TextEditingController();
  final _share = TextEditingController(text: '壹ZHANG核');

  bool _testing = false;
  bool _syncing = false;
  String? _lastResult;

  @override
  void dispose() {
    _bucket.dispose();
    _region.dispose();
    _secretId.dispose();
    _secretKey.dispose();
    _share.dispose();
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
        title: Text('云同步', style: TextStyle(color: Tokens.text, fontSize: Tokens.fsEmph)),
        iconTheme: IconThemeData(color: Tokens.text),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
          ],
        ),
      ),
    );
  }

  Widget _intro() => Text(
        '把收藏数据（数据库 + 全部原图）单向备份到腾讯云对象存储。本地优先、原图原文件、不压缩。',
        style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint),
      );

  // ---- 配置块 ----
  Widget _configBlock(SyncConfig? cfg) => _block('腾讯云 COS 配置${cfg != null ? '（已配置）' : ''}', [
        _field(_bucket, '存储桶 Bucket（腾讯云控制台里的桶名，形如 yizhanghe-1250000000）'),
        const SizedBox(height: 10),
        _field(_region, '地域 Region（如 ap-guangzhou）'),
        const SizedBox(height: 10),
        _field(_secretId, 'SecretId'),
        const SizedBox(height: 10),
        _field(_secretKey, 'SecretKey', obscure: true),
        const SizedBox(height: 10),
        _field(_share, '远端目录前缀', hint: '壹ZHANG核'),
        const SizedBox(height: 8),
        Text('在腾讯云控制台「访问管理 → API 密钥管理」获取 SecretId/SecretKey；'
            '存储桶需带 AppId 后缀。密钥只保存在本机。',
            style: TextStyle(color: Tokens.faint, fontSize: Tokens.fsLabel)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _btn('测试连接', _testing, _testConnect, accent: false)),
          const SizedBox(width: 10),
          Expanded(child: _btn(cfg != null ? '保存配置' : '保存并启用', false, _save)),
        ]),
      ]);

  // ---- 同步块 ----
  Widget _syncBlock() => _block('立即备份', [
        Text('扫描本地全部数据并上传到云端。已上传且未变化的文件会自动跳过。',
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        const SizedBox(height: 12),
        _btn('开始备份到云端', _syncing, _runSync, accent: true),
        const SizedBox(height: 10),
        _btn('校验云端完整性', false, _verify, accent: false),
      ]);

  Widget _statusLine() => _lastResult == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_lastResult!, style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
        );

  // ---- 组件 ----
  Widget _block(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title,
                style: TextStyle(
                    color: Tokens.muted, fontSize: Tokens.fsHint, fontWeight: FontWeight.w700)),
          ),
          NeumorphicBox(
              radius: Tokens.rCard,
              padding: const EdgeInsets.all(16),
              child: Column(children: children)),
        ]);

  Widget _field(TextEditingController c, String label,
          {bool obscure = false, String? hint}) =>
      NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: c,
          obscureText: obscure,
          style: TextStyle(color: Tokens.text, fontSize: Tokens.fsBody),
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            labelStyle: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint),
            hintStyle: TextStyle(color: Tokens.faint),
          ),
        ),
      );

  Widget _btn(String label, bool busy, VoidCallback onTap, {bool accent = false}) =>
      GestureDetector(
        onTap: busy ? null : onTap,
        child: NeumorphicBox(
          state: busy ? NeuState.inset : NeuState.raised,
          radius: Tokens.rBtn,
          color: accent ? Tokens.accentSoft : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Tokens.accent, strokeWidth: 2))
                : Text(label,
                    style: TextStyle(
                        color: accent ? Tokens.seal : Tokens.accent,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      );

  // ---- 逻辑 ----
  SyncConfig _buildConfig() => SyncConfig(
        bucket: _bucket.text.trim(),
        region: _region.text.trim(),
        secretId: _secretId.text.trim(),
        secretKey: _secretKey.text,
        remoteBasePath:
            _share.text.trim().isEmpty ? '壹ZHANG核' : _share.text.trim(),
      );

  void _fillForm(SyncConfig cfg) {
    if (_bucket.text.isEmpty) {
      _bucket.text = cfg.bucket;
      _region.text = cfg.region;
      _secretId.text = cfg.secretId;
      _secretKey.text = cfg.secretKey;
      if (cfg.remoteBasePath.isNotEmpty) _share.text = cfg.remoteBasePath;
    }
  }

  Future<void> _testConnect() async {
    setState(() => _testing = true);
    try {
      final cfg = _buildConfig();
      if (!cfg.isValid) throw StateError('请先填写完整：Bucket / Region / SecretId / SecretKey');
      await CosClient(cfg).testConnection();
      _toast('连接成功');
    } catch (e) {
      _toast('连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final cfg = _buildConfig();
    if (!cfg.isValid) {
      _toast('请先填写完整：Bucket / Region / SecretId / SecretKey');
      return;
    }
    await SyncConfigStore.save(cfg);
    setState(() => _savedCfgFuture = Future.value(cfg));
    _toast('配置已保存');
  }

  Future<void> _runSync() async {
    setState(() => _syncing = true);
    try {
      final root = await PlatformPaths.appDataDir();
      final orch = CloudSyncOrchestrator(onProgress: (done, total, f) {
        if (mounted && (done % 10 == 0 || done == total - 1)) {
          setState(() => _lastResult = '进度：$done / $total（$f）');
        }
      });
      final r = await orch.backupAll(root);
      _toast('备份完成：上传 ${r.uploaded}，跳过 ${r.skipped}，失败 ${r.failed}');
      if (r.errors.isNotEmpty) {
        setState(() => _lastResult = '失败明细：\n${r.errors.take(5).join('\n')}');
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
      final ok = await CloudSyncOrchestrator().verifyRemoteSizes(root);
      _toast(ok ? '云端完整性校验通过' : '发现不一致，建议重新备份');
    } catch (e) {
      _toast('校验失败：$e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}