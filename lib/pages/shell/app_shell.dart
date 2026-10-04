import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../collection/collection_page.dart';
import '../stats/stats_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;
  final _pages = const [CollectionPage(), StatsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Tokens.bg,
        body: IndexedStack(index: _i, children: _pages),
        // 底部导航：照定稿原型 .botnav（height:60 / 圆角顶22 / 三段 flex:1 / 纵向居中 / padding6 / gap6）
        // 用通栏 + SafeArea 防折叠屏系统导航栏遮挡，解决"很小很奇怪"。
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Tokens.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                      child: _NavItem(
                          idx: 0,
                          current: _i,
                          icon: Icons.collections,
                          label: '文玩',
                          onTap: () {
                            if (_i == 0) return;
                            setState(() => _i = 0);
                          })),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _NavItem(
                          idx: 1,
                          current: _i,
                          icon: Icons.bar_chart,
                          label: '统计',
                          onTap: () {
                            if (_i == 1) return;
                            setState(() => _i = 1);
                          })),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _NavItem(
                          idx: 2,
                          current: _i,
                          icon: Icons.settings,
                          label: '设置',
                          onTap: () {
                            if (_i == 2) return;
                            setState(() => _i = 2);
                          })),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 单个底栏按钮：默认凸起，active 用 accentSoft 加深（不用阴影切换），
/// 按下时 NeuState.pressed = inSm 凹陷 — 与「时间 ↓」触感一致
class _NavItem extends StatefulWidget {
  final int idx;
  final int current;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavItem(
      {required this.idx,
      required this.current,
      required this.icon,
      required this.label,
      required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.idx == widget.current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: NeumorphicBox(
        state: _pressed ? NeuState.pressed : NeuState.raised,
        radius: 16,
        color: on ? Tokens.accentSoft : Tokens.bg,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: on ? 1.16 : 1.0,
              child: Icon(widget.icon,
                  color: on ? Tokens.accent : Tokens.muted, size: 20),
            ),
            const SizedBox(height: 3),
            Text(widget.label,
                style: TextStyle(
                    color: on ? Tokens.accent : Tokens.muted,
                    fontSize: Tokens.fsHint,
                    fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
