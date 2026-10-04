import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/tokens.dart';
import '../../theme/nu.dart';
import '../../logic/providers.dart';
import '../../logic/format.dart';
import '../../logic/delete_helper.dart';
import '../../data/models/enums.dart';
import '../../data/models/walnut.dart';
import '../../data/models/item.dart';
import '../../widgets/cover_thumb.dart';
import '../../widgets/swipe_reveal.dart';
import 'walnut_detail_page.dart';
import 'item_detail_page.dart';
import 'add_walnut_sheet.dart';
import 'add_item_sheet.dart';

class CollectionPage extends ConsumerWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(collectionTabProvider);
    final lv = ref.watch(collectionMenuLvProvider);
    final sub = ref.watch(collectionSubProvider);
    final group = ref.watch(collectionGroupProvider);
    final variety = ref.watch(collectionVarietyProvider);

    // curCat 持久（照原型）：tab 为核桃时看核桃，否则按二级 sub 看其他类
    final isWalnut = tab == '核桃';
    // 按 tab 只订阅需要的那一路数据：原来同时 watch 两路，
    // 每次切 tab / 改筛选都会同时触发两次全表查询，是卡顿主因之一
    final walnuts = isWalnut ? ref.watch(walnutsProvider) : null;
    final items = isWalnut ? null : ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, ref, isWalnut),
            _catMenu(ref, tab, lv, sub),
            _crumb(isWalnut, sub, group, variety),
            _filters(context, ref, isWalnut, group, variety),
            const SizedBox(height: 8),
            Expanded(
              // 只处理当前 tab 那一路数据，避免嵌套 when 的双层重建
              child: isWalnut
                  ? walnuts!.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                      data: (wn) => _listBody(context, ref, isWalnut, wn, const [],
                          group, variety, sub),
                    )
                  : items!.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                      data: (it) => _listBody(context, ref, isWalnut, const [], it,
                          group, '', sub),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏：标题居中 + 右上角独立「＋新增」（照定稿原型 appbar 三段式）
  Widget _header(BuildContext context, WidgetRef ref, bool isWalnut) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SizedBox(), // 左占位，保证标题真正居中
          ),
          Text('文玩档案',
              style: TextStyle(
                  fontSize: Tokens.fsEmph,
                  fontWeight: FontWeight.bold,
                  color: Tokens.text)),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _openAdd(context, ref, isWalnut),
                child: NeumorphicBox(
                  state: NeuState.inset,
                  radius: Tokens.rBtn,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                  child: Text('＋新增',
                      style: TextStyle(
                          fontSize: Tokens.fsBody,
                          fontWeight: FontWeight.w700,
                          color: Tokens.accent)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 两级子菜单（照定稿原型 renderCatMenu）：
  /// 一级 = 核桃 / 其他；点「其他」进二级（手串·吊坠·手把件·摆件 + ‹返回）
  Widget _catMenu(WidgetRef ref, String tab, int lv, String sub) {
    if (lv == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          children: [
            Expanded(child: _catTab(ref, '核桃', tab == '核桃', () {
              ref.read(collectionTabProvider.notifier).state = '核桃';
              ref.read(collectionMenuLvProvider.notifier).state = 1;
              ref.read(collectionGroupProvider.notifier).state = '';
              ref.read(collectionVarietyProvider.notifier).state = '';
            })),
            const SizedBox(width: 8),
            Expanded(child: _catTab(ref, '其他', tab == '其他', () {
              ref.read(collectionTabProvider.notifier).state = '其他';
              ref.read(collectionMenuLvProvider.notifier).state = 2;
              // 原型：进入其他时若当前类型不在四类内，落到「手串」
              ref.read(collectionGroupProvider.notifier).state = '';
            })),
          ],
        ),
      );
    }
    // 二级：纵向容器 + 返回 + 四类横排
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => ref.read(collectionMenuLvProvider.notifier).state = 1,
            child: NeumorphicBox(
              state: NeuState.raised,
              radius: Tokens.rBtn,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text('‹ 返回',
                  style: TextStyle(
                      fontSize: Tokens.fsBody,
                      fontWeight: FontWeight.w600,
                      color: Tokens.muted)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in itemTypes) ...[
                Expanded(
                    child: _catTab(ref, t, sub == t, () => _pickOther(ref, t))),
                if (t != itemTypes.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 选中其他类的某个类型：换二级类型 → 清空材质筛选（照原型 afterCat）
  void _pickOther(WidgetRef ref, String t) {
    ref.read(collectionSubProvider.notifier).state = t;
    ref.read(collectionGroupProvider.notifier).state = '';
    ref.read(collectionVarietyProvider.notifier).state = '';
  }

  Widget _catTab(WidgetRef ref, String label, bool on, VoidCallback onTap) {
    // 统一：默认 raised 凸起，on 也 raised 但 color 加深（不用阴影切换 active 状态）
    // 按下时 NeuState.pressed = inSm 凹陷 =「时间 ↓」触感
    return _PressableTab(label: label, on: on, onTap: onTap);
  }

  /// 面包屑（照定稿原型 updateCrumb 逐条翻译）：
  /// 核桃 = 文玩档案 › 核桃 [› 品类 [› 品种]]；其他 = 文玩档案 › 其他 › 类型 [› 材质]
  Widget _crumb(bool isWalnut, String sub, String group, String variety) {
    final String head;
    String seg3 = '';
    if (isWalnut) {
      head = '核桃';
      if (group.isNotEmpty) {
        seg3 = variety.isNotEmpty ? '$group › $variety' : group;
      }
    } else {
      head = '其他 › $sub';
      if (group.isNotEmpty) seg3 = group;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '文玩档案 › ',
              style: TextStyle(
                  fontSize: Tokens.fsHint, color: Tokens.faint)),
          TextSpan(
              text: seg3.isEmpty ? head : '$head › $seg3',
              style: TextStyle(
                  fontSize: Tokens.fsHint,
                  color: Tokens.muted,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// 筛选区（照定稿原型 buildFilters）：
  /// 核桃 = 大品类 + 品种两级级联（未选品类时品种置灰「请先选品类」）；
  /// 其他 = 单个材质下拉
  Widget _filters(BuildContext context, WidgetRef ref, bool isWalnut,
      String group, String variety) {
    if (isWalnut) {
      final varieties =
          group.isEmpty ? const <String>[] : (walnutVarieties[group] ?? const []);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Row(
          children: [
            Expanded(
                child: _selectBox(
              context,
              group.isEmpty ? '全部品类' : group,
              walnutCategories,
              (v) {
                ref.read(collectionGroupProvider.notifier).state =
                    v == '全部品类' ? '' : v;
                ref.read(collectionVarietyProvider.notifier).state = '';
              },
            )),
            const SizedBox(width: 9),
            Expanded(
              child: varieties.isEmpty
                  ? _disabledBox('请先选品类')
                  : _selectBox(
                      context,
                      variety.isEmpty ? '全部品种' : variety,
                      ['全部品种', ...varieties],
                      (v) => ref.read(collectionVarietyProvider.notifier).state =
                          v == '全部品种' ? '' : v,
                    ),
            ),
          ],
        ),
      );
    }
    // 其他分支：材质单选（树籽 / 牙骨角 / 木质 / 矿石）
    final mats = itemCategoryVariety.keys.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(children: [
        Expanded(
            child: _selectBox(
                context, group.isEmpty ? '全部品类' : group, ['全部品类', ...mats],
                (v) {
          ref.read(collectionGroupProvider.notifier).state =
              v == '全部品类' ? '' : v;
        })),
      ]),
    );
  }

  /// 新拟态下拉：外观用凹陷框 + 弹出底部菜单选项（等价原型 <select>）
  Widget _selectBox(BuildContext context, String current,
      List<String> options, ValueChanged<String> onPick) {
    return GestureDetector(
      onTap: () => _openSelect(context, current, options, onPick),
      child: NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(current,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: Tokens.fsBody, color: Tokens.text)),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: Tokens.muted),
          ],
        ),
      ),
    );
  }

  Widget _disabledBox(String label) => NeumorphicBox(
        state: NeuState.inset,
        radius: Tokens.rInput,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: Tokens.fsBody, color: Tokens.faint))),
          Icon(Icons.arrow_drop_down, size: 18, color: Tokens.faint),
        ]),
      );

  Future<void> _openSelect(BuildContext context, String current,
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
                    color: o == current ? Tokens.accentSoft : Tokens.bg,
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
                        Icon(Icons.check,
                            size: 18, color: Tokens.accent),
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

  Widget _listBody(BuildContext context, WidgetRef ref, bool isWalnut,
      List<Walnut> wn, List<Item> it, String group, String variety,
      String sub) {
    final list = _buildList(ref, isWalnut, wn, it, group, variety, sub);
    if (list.isEmpty) {
      return Center(
        child: Text('这里还空空如也\n点击右上角「＋新增」添加第一件',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Tokens.muted, fontSize: Tokens.fsHint)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async { refreshCollection(ref); },
      color: Tokens.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => list[i],
      ),
    );
  }

  /// 过滤规则（照定稿原型 renderCards）：
  /// 核桃 = 大品类 + 品种；其他 = 二级类型 + 材质
  /// 注意：原型的 curCat 是持久状态，menuLv 只控制菜单收放——
  /// 所以即使点「‹ 返回」收起到一级，列表仍按当前二级类型过滤，不可改成 lv==2 才过滤。
  List<Widget> _buildList(WidgetRef ref, bool isWalnut, List<Walnut> wn, List<Item> it,
      String group, String variety, String sub) {
    if (isWalnut) {
      var filtered = wn;
      if (group.isNotEmpty) {
        filtered = filtered.where((w) => w.category == group).toList();
      }
      if (variety.isNotEmpty) {
        filtered = filtered.where((w) => w.variety == variety).toList();
      }
      return filtered.map((w) => _walnutCard(w, ref)).toList();
    }
    var filtered = it.where((e) => e.type == sub).toList();
    if (group.isNotEmpty) {
      filtered = filtered.where((e) => e.category == group).toList();
    }
    return filtered.map((i) => _itemCard(i, ref)).toList();
  }

  Widget _walnutCard(Walnut w, WidgetRef ref) => Builder(builder: (ctx) {
        return SwipeReveal(
      rowOnTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => WalnutDetailPage(w))),
      actions: [
        SwipeAction(icon: Icons.edit_outlined, label: '编辑', color: Tokens.accent,
            onTap: () => _edit(ctx, ref, true, w)),
        SwipeAction(icon: Icons.delete_outline, label: '删除', color: Tokens.badD10,
            onTap: () => _confirmDelete(ctx, ref, isWalnut: true, id: w.id, name: w.name)),
      ],
      child: Stack(children: [
            NeumorphicBox(
            radius: Tokens.rCard,
            // 右侧留 34 给右上角的 ✎ 编辑按钮，避免压住名称/价格
            padding: const EdgeInsets.fromLTRB(14, 14, 34, 14),
            child: Row(
              children: [
                CoverThumb(rel: w.coverPath, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: TextStyle(fontSize: Tokens.fsBody, fontWeight: FontWeight.w600, color: Tokens.text)),
                      const SizedBox(height: 4),
                      Text('${w.category}·${w.variety}', style: TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(w.code, style: TextStyle(fontSize: Tokens.fsLabel, color: Tokens.faint)),
                          const Spacer(),
                          Text(formatPrice(w.price), style: TextStyle(fontSize: Tokens.fsBody, color: Tokens.accent, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: patinaTags(full: w.full, repaired: w.repaired, yellow: w.yellow)
                          .map((t) => _tag(t)).toList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
            // CI 反馈 #7：卡片右上角直接编辑，不用右滑
            Positioned(top: 6, right: 6, child: _editBtn(ctx, ref, true, w)),
          ]),
        );
      });

  Widget _itemCard(Item i, WidgetRef ref) => Builder(builder: (ctx) {
        return SwipeReveal(
      rowOnTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => ItemDetailPage(i))),
      actions: [
        SwipeAction(icon: Icons.edit_outlined, label: '编辑', color: Tokens.accent,
            onTap: () => _edit(ctx, ref, false, i)),
        SwipeAction(icon: Icons.delete_outline, label: '删除', color: Tokens.badD10,
            onTap: () => _confirmDelete(ctx, ref, isWalnut: false, id: i.id,
                name: i.name.isNotEmpty ? i.name : i.type)),
      ],
      child: Stack(children: [
            NeumorphicBox(
            radius: Tokens.rCard,
            // 右侧留 34 给右上角的 ✎ 编辑按钮
            padding: const EdgeInsets.fromLTRB(14, 14, 34, 14),
            child: Row(
              children: [
                CoverThumb(rel: i.coverPath, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name.isNotEmpty ? i.name : i.type, style: TextStyle(fontSize: Tokens.fsBody, fontWeight: FontWeight.w600, color: Tokens.text)),
                      const SizedBox(height: 4),
                      Text('${i.category}·${i.variety}', style: TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(formatSize(i.sizeMm), style: TextStyle(fontSize: Tokens.fsLabel, color: Tokens.faint)),
                          const Spacer(),
                          Text(formatPrice(i.price), style: TextStyle(fontSize: Tokens.fsBody, color: Tokens.accent, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
            // CI 反馈 #7：卡片右上角直接编辑
            Positioned(top: 6, right: 6, child: _editBtn(ctx, ref, false, i)),
          ]),
        );
      });

  /// 卡片右上角编辑按钮（CI 反馈 #7）
  Widget _editBtn(BuildContext ctx, WidgetRef ref, bool isWalnut, dynamic r) =>
      GestureDetector(
        onTap: () => _edit(ctx, ref, isWalnut, r),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Tokens.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.edit_outlined, size: 16, color: Tokens.accent),
        ),
      );

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Tokens.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: Tokens.fsLabel, color: Tokens.accent)),
      );

  /// 编辑：打开全屏新增页并预填，保存即覆盖原记录（CI 反馈 #1 全屏）
  void _edit(BuildContext ctx, WidgetRef ref, bool isWalnut, dynamic record) {
    Navigator.of(ctx)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => isWalnut
              ? AddWalnutSheet(editWalnut: record as Walnut)
              : AddItemSheet(editItem: record as Item),
        ))
        .then((_) => refreshCollection(ref));
  }

  /// 删除确认（二次确认，防误触）
  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref,
      {required bool isWalnut, required int? id, required String name}) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「$name」及其全部原图，不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || id == null) return;
    // 连原图目录一起清（patina 行不会自动级联，需显式删）
    if (isWalnut) {
      await DeleteHelper.walnut(id);
    } else {
      await DeleteHelper.item(id);
    }
    ref.invalidate(walnutsProvider);
    ref.invalidate(itemsProvider);
  }

  void _openAdd(BuildContext context, WidgetRef ref, bool isWalnut) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              isWalnut ? const AddWalnutSheet() : const AddItemSheet(),
        ))
        .then((_) => refreshCollection(ref));
  }
}

/// 子菜单 tab：默认 NeuState.raised 凸起，on 时 color=accentSoft 加深（不用阴影切换），
/// 按压 NeuState.pressed = inSm 凹陷 — 与「时间 ↓」（ctrl-sort）一致
class _PressableTab extends StatefulWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _PressableTab({required this.label, required this.on, required this.onTap});
  @override
  State<_PressableTab> createState() => _PressableTabState();
}

class _PressableTabState extends State<_PressableTab> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: NeumorphicBox(
        state: _pressed ? NeuState.pressed : NeuState.raised,
        radius: Tokens.rBtn,
        color: widget.on ? Tokens.accentSoft : Tokens.bg,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: Tokens.fsBody,
                  fontWeight: widget.on ? FontWeight.w700 : FontWeight.w600,
                  color: widget.on ? Tokens.accent : Tokens.muted)),
        ),
      ),
    );
  }
}
