import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/nu.dart';

/// 新拟态下拉选择框（等价原型 <select>）：
/// 外观 = 凹陷框 + 右侧 ▾；点击弹出底部菜单选一项。
/// 用于「入手平台」等必须从候选里选、不能手打的字段（CI 反馈 #6）。
class NeuSelect extends StatelessWidget {
  final String label;
  final String current;
  final List<String> options;
  final ValueChanged<String> onPick;
  final bool enabled;

  const NeuSelect({
    super.key,
    this.label = '',
    required this.current,
    required this.options,
    required this.onPick,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label,
              style:
                  TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: enabled ? () => openNeuSelect(context, current, options, onPick) : null,
          child: NeumorphicBox(
            state: NeuState.inset,
            radius: Tokens.rInput,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Expanded(
                child: Text(
                  current.isEmpty ? '请选择' : current,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: Tokens.fsBody,
                      color: enabled ? Tokens.text : Tokens.faint),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 18, color: Tokens.muted),
            ]),
          ),
        ),
      ],
    );
  }
}

/// 弹出底部选项菜单，返回选中值
Future<void> openNeuSelect(BuildContext context, String current,
    List<String> options, ValueChanged<String> onPick) async {
  final v = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (c) => Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.6),
      decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => Navigator.pop(c, o),
                child: NeumorphicBox(
                  state: o == current ? NeuState.raised : NeuState.inset,
                  radius: Tokens.rInput,
                  color: o == current ? Tokens.accentSoft : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  child: Row(children: [
                    Expanded(
                      child: Text(o,
                          style: TextStyle(
                              fontSize: Tokens.fsBody,
                              color: o == current
                                  ? Tokens.accent
                                  : Tokens.text,
                              fontWeight: o == current
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ),
                    if (o == current)
                      Icon(Icons.check, size: 18, color: Tokens.accent),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  if (v != null) onPick(v);
}
