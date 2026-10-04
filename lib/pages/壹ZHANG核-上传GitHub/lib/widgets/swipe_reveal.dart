import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 左滑操作项
class SwipeAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  SwipeAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = Tokens.accent});
}

/// 列表行左滑露出快捷操作。
/// · 手指向左拖动，跟随手指实时位移
/// · 露出操作区后松手，若未超过阈值则自动回弹
/// · 点击操作后自动回弹并执行回调
/// · 未展开时点击整行仍触发 rowOnTap，不影响原有跳转
class SwipeReveal extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final VoidCallback? rowOnTap;
  const SwipeReveal(
      {super.key,
      required this.child,
      required this.actions,
      this.rowOnTap});

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  double _dragX = 0;
  // 上一次动画的 listener。原来每次 _animateTo 都 addListener 却从不移除，
  // 滑几次后多个 listener 各自用不同的 begin 同时 setState → 回弹抖动。
  VoidCallback? _listener;

  double get _actionWidth => 64.0 * widget.actions.length;

  void _animateTo(double target) {
    _c.stop();
    if (_listener != null) _c.removeListener(_listener!);
    final begin = _dragX;
    _c.reset();
    final l = () {
      setState(() => _dragX = begin + (target - begin) * _c.value);
    };
    _listener = l;
    _c.addListener(l);
    _c.forward();
  }

  void _close() => _animateTo(0);

  @override
  void dispose() {
    if (_listener != null) _c.removeListener(_listener!);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        _c.stop();
        setState(() {
          var x = _dragX + d.delta.dx;
          if (x > 0) x = 0; // 只允许左滑
          if (x < -_actionWidth - 40) x = -_actionWidth - 40;
          _dragX = x;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_dragX < -_actionWidth / 2) {
          _animateTo(-_actionWidth);
        } else {
          _animateTo(0);
        }
      },
      onTap: () {
        if (_dragX != 0) {
          _close();
        } else {
          widget.rowOnTap?.call();
        }
      },
      child: Stack(
        children: [
          // 底层：操作区
          if (_dragX < 0)
            Positioned.fill(
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: widget.actions
                    .map((a) => SizedBox(
                          width: 64,
                          child: InkWell(
                            onTap: () {
                              _close();
                              a.onTap();
                            },
                            child: Container(
                              color: a.color,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(a.icon, color: Colors.white, size: 20),
                                  const SizedBox(height: 3),
                                  Text(a.label,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          // 上层：内容，可左右位移
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
