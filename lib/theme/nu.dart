import 'package:flutter/material.dart';
import 'tokens.dart';

// Neumorphism 组件库（新拟态）：凸起 / 凹陷 / 按压 三态
// 全站页面复用，保证与定稿 HTML 原型视觉一致。

enum NeuState { raised, inset, pressed }

// 基础新拟态容器：同一底色 + 双向投影做凸凹
class NeumorphicBox extends StatelessWidget {
  final Widget? child;
  final double radius;
  final EdgeInsets? padding;
  final NeuState state;
  final double? width;
  final double? height;
  // 可空：不传时取当前主题的 Tokens.bg，保证切主题后底色跟随
  final Color? color;

  const NeumorphicBox({
    super.key,
    this.child,
    this.radius = Tokens.rCard,
    this.padding,
    this.state = NeuState.raised,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shadows = switch (state) {
      NeuState.raised => Tokens.out,
      NeuState.inset => Tokens.inShadow,
      NeuState.pressed => Tokens.inSm,
    };
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Tokens.bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadows,
        ),
        child: child,
      ),
    );
  }
}

// 新拟态按钮：默认凸起，按下翻转凹陷（按压反馈）
class NeuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double? width;
  const NeuButton({super.key, required this.label, this.onTap, this.width});

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  // 按压反馈：只做位移，不切换阴影。
  // 原因：阴影切换会强制重新光栅化模糊层，是卡顿主因；位移几乎零成本。
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) {
        _set(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _set(false),
      child: Transform.translate(
        offset: Offset(0, _pressed ? 1.5 : 0),
        child: Opacity(
          opacity: _pressed ? 0.82 : 1,
          child: NeumorphicBox(
            state: NeuState.raised, // 阴影恒定，不再随按压重建
            radius: Tokens.rBtn,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              widget.label,
              style: TextStyle(
                  fontSize: Tokens.fsBody,
                  color: Tokens.accent,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// 新拟态输入框：常驻凹陷；聚焦时描朱砂边 + 自动滚到键盘上方 + 回车跳下一栏
class NeuTextField extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  const NeuTextField({
    super.key,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() {}); // 刷新聚焦描边
      if (!_focus.hasFocus) return;
      // 键盘弹出需要时间，延迟到键盘就位后再把当前字段滚到键盘上方。
      // 没有这一步：折叠屏上键盘占近半屏，正在编辑的内容会被键盘盖住一半。
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || !context.mounted) return;
        Scrollable.ensureVisible(context,
            duration: const Duration(milliseconds: 250),
            alignment: 0.15,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit);
      });
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.rInput),
        border: Border.all(
          color: focused ? Tokens.seal : Colors.transparent,
          width: focused ? 2 : 0,
        ),
      ),
      child: NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          focusNode: _focus,
          textInputAction: widget.textInputAction ?? TextInputAction.next,
          // 回车 = 跳下一栏（最后一栏无下一项则原地不动），不再先收键盘
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                TextStyle(color: Tokens.faint, fontSize: Tokens.fsBody),
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          style: TextStyle(
              color: Tokens.text,
              fontSize: Tokens.fsInput,
              height: 1.1),
        ),
      ),
    );
  }
}

// 新拟态筛选 chip：选中凸起(强调)，未选凹陷(锁定)
class NeuChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const NeuChip(
      {super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicBox(
        state: active ? NeuState.raised : NeuState.inset,
        radius: Tokens.rPill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: active ? Tokens.accentSoft : Tokens.bg,
        child: Text(
          label,
          style: TextStyle(
            fontSize: Tokens.fsHint,
            color: active ? Tokens.accent : Tokens.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// 新拟态开关：凹陷轨道 + 凸起圆点
class NeuSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const NeuSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rPill,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: NeumorphicBox(
            state: NeuState.raised,
            radius: Tokens.rPill,
            width: 24,
            height: 24,
            color: value ? Tokens.accent : Tokens.bg,
          ),
        ),
      ),
    );
  }
}
