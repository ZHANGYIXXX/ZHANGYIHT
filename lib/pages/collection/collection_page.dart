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

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 搜索框实时写入 provider（NeuTextField 无 onChanged，这里用原生 TextField + listener）
    _searchCtl.addListener(() {
      ref.read(collectionSearchProvider.notifier).state = _searchCtl.text;
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = ref.watch(collectionCatProvider);
    final filter = ref.watch(collectionFilterProvider);
    final search = ref.watch(collectionSearchProvider);
    final walnutsAsync = ref.watch(walnutsProvider);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, ref),
            _searchRow(),
            _catTabs(ref, cat),
            _filterRow(context, ref, walnutsAsync, itemsAsync, cat, filter),
            const SizedBox(height: 8),
            Expanded(
              child: _body(walnutsAsync, itemsAsync, cat, filter, search, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏：标题居中 + 右上角独立「＋新增」
  Widget _header(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          const Expanded(flex: 1, child: SizedBox()),
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
                onTap: () => _openAdd(context, ref),
                child: NeumorphicBox(
                  state: NeuState.inset,
                  radius: Tokens.rBtn,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
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

  /// 搜索框：模糊匹配名称或品类（如输入「大蒜头」直接定位）
  Widget _searchRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: NeumorphicBox(
          state: NeuState.inset,
          radius: Tokens.rInput,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: Tokens.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtl,
                  style: TextStyle(fontSize: Tokens.fsBody, color: Tokens.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '搜索名称或品类，如：大蒜头',
                    hintStyle: TextStyle(color: Tokens.faint, fontSize: Tokens.fsBody),
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              if (_searchCtl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => _searchCtl.clear(),
                  child: Icon(Icons.close, size: 18, color: Tokens.muted),
                ),
            ],
          ),
        ),
      );

  /// 扁平一级分类 tab：全部 / 核桃 / 手串 / 吊坠 / 手把件 / 摆件
  /// 点击任意分类即重置二级品类筛选为「全部品类」
  Widget _catTabs(WidgetRef ref, String cat) {
    final tabs = [allCat, ...categories];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tabs) ...[
              _catTab(ref, t, cat == t, () {
                ref.read(collectionCatProvider.notifier).state = t;
                ref.read(collectionFilterProvider.notifier).state = '';
              }),
              if (t != tabs.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _catTab(WidgetRef ref, String label, bool on, VoidCallback onTap) =>
      _PressableTab(label: label, on: on, onTap: onTap);

  /// 二级品类下拉（合并原「全部品类」+「右边品类」两项）：
  /// 直接列出当前数据里手填的品类名称并带计数，选择即按该名称过滤
  Widget _filterRow(BuildContext context, WidgetRef ref,
      AsyncValue<List<Walnut>> wA, AsyncValue<List<Item>> iA, String cat, String filter) {
    final counts = <String, int>{};
    void addCats(List<String> cats) {
      for (final c in cats) {
        if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
      }
    }

    if (cat == allCat || cat == '核桃') {
      final wn = wA.value;
      if (wn != null) addCats(wn.map((w) => w.category).toList());
    }
    if (cat == allCat || cat != '核桃') {
      final it = iA.value;
      if (it != null) {
        final visible = cat == allCat ? it : it.where((e) => e.type == cat).toList();
        addCats(visible.map((e) => e.category).toList());
      }
    }

    final rawOpts = counts.keys.toList()..sort();
    final displayOpts = <String>['全部品类', ...rawOpts.map((o) => '$o (${counts[o]})')];
    final currentLabel = filter.isEmpty ? '全部品类' : '$filter (${counts[filter] ?? 0})';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: _selectBox(context, currentLabel, displayOpts, (v) {
        final idx = displayOpts.indexOf(v);
        if (idx <= 0) {
          ref.read(collectionFilterProvider.notifier).state = '';
        } else {
          ref.read(collectionFilterProvider.notifier).state = rawOpts[idx - 1];
        }
      }),
    );
  }

  /// 新拟态下拉：凹陷框 + 底部弹出选项（等价原型 <select>）
  Widget _selectBox(BuildContext context, String current, List<String> options,
      ValueChanged<String> onPick) {
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
                  style: TextStyle(fontSize: Tokens.fsBody, color: Tokens.text)),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: Tokens.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _openSelect(BuildContext context, String current, List<String> options,
      ValueChanged<String> onPick) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.6),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(children: [
                      Expanded(
                        child: Text(o,
                            style: TextStyle(
                                fontSize: Tokens.fsBody,
                                color: o == current ? Tokens.accent : Tokens.text,
                                fontWeight: o == current ? FontWeight.w700 : FontWeight.normal)),
                      ),
                      if (o == current) Icon(Icons.check, size: 18, color: Tokens.accent),
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

  Widget _body(AsyncValue<List<Walnut>> wA, AsyncValue<List<Item>> iA,
      String cat, String filter, String search, WidgetRef ref) {
    if (cat == '核桃') {
      return wA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (wn) => _listBody(ref,
            _filterWalnuts(wn, filter, search).map((w) => _walnutCard(w, ref)).toList()),
      );
    }
    if (cat == allCat) {
      return wA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (wn) => iA.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (it) => _listBody(ref, [
            ..._filterWalnuts(wn, filter, search).map((w) => _walnutCard(w, ref)),
            ..._filterItems(it, cat, filter, search).map((e) => _itemCard(e, ref)),
          ]),
        ),
      );
    }
    return iA.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (it) => _listBody(ref,
          _filterItems(it, cat, filter, search).map((e) => _itemCard(e, ref)).toList()),
    );
  }

  List<Walnut> _filterWalnuts(List<Walnut> all, String filter, String search) {
    var l = all;
    if (filter.isNotEmpty) l = l.where((w) => w.category == filter).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      l = l
          .where((w) =>
              w.name.toLowerCase().contains(q) || w.category.toLowerCase().contains(q))
          .toList();
    }
    return l;
  }

  List<Item> _filterItems(List<Item> all, String cat, String filter, String search) {
    var l = cat == allCat ? all : all.where((e) => e.type == cat).toList();
    if (filter.isNotEmpty) l = l.where((e) => e.category == filter).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      l = l
          .where((e) {
            final name = e.name.isNotEmpty ? e.name : e.type;
            return name.toLowerCase().contains(q) || e.category.toLowerCase().contains(q);
          })
          .toList();
    }
    return l;
  }

  Widget _listBody(WidgetRef ref, List<Widget> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('这里还空空如也\n点击右上角「＋新增」添加第一件',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tokens.muted, fontSize: Tokens.fsHint)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        refreshCollection(ref);
      },
      color: Tokens.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => list[i],
      ),
    );
  }

  /// 卡片副标题：品类·品种（品种为空时只显品类）
  String _sub(String cat, String var_) => var_.isEmpty ? cat : '$cat·$var_';

  Widget _walnutCard(Walnut w, WidgetRef ref) => Builder(builder: (ctx) {
        return SwipeReveal(
          rowOnTap: () => Navigator.of(ctx)
              .push(MaterialPageRoute(builder: (_) => WalnutDetailPage(w))),
          actions: [
            SwipeAction(
                icon: Icons.edit_outlined,
                label: '编辑',
                color: Tokens.accent,
                onTap: () => _edit(ctx, ref, true, w)),
            SwipeAction(
                icon: Icons.delete_outline,
                label: '删除',
                color: Tokens.badD10,
                onTap: () => _confirmDelete(ctx, ref,
                    isWalnut: true, id: w.id, name: w.name)),
          ],
          child: Stack(children: [
            NeumorphicBox(
              radius: Tokens.rCard,
              padding: const EdgeInsets.fromLTRB(14, 14, 34, 14),
              child: Row(
                children: [
                  CoverThumb(rel: w.coverPath, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name,
                            style: TextStyle(
                                fontSize: Tokens.fsBody,
                                fontWeight: FontWeight.w600,
                                color: Tokens.text)),
                        const SizedBox(height: 4),
                        Text(_sub(w.category, w.variety),
                            style: TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(w.code,
                                style: TextStyle(
                                    fontSize: Tokens.fsLabel, color: Tokens.faint)),
                            const Spacer(),
                            Text(formatPrice(w.price),
                                style: TextStyle(
                                    fontSize: Tokens.fsBody,
                                    color: Tokens.accent,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            children: patinaTags(
                                    full: w.full,
                                    repaired: w.repaired,
                                    yellow: w.yellow)
                                .map((t) => _tag(t))
                                .toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 6, right: 6, child: _editBtn(ctx, ref, true, w)),
          ]),
        );
      });

  Widget _itemCard(Item i, WidgetRef ref) => Builder(builder: (ctx) {
        return SwipeReveal(
          rowOnTap: () => Navigator.of(ctx)
              .push(MaterialPageRoute(builder: (_) => ItemDetailPage(i))),
          actions: [
            SwipeAction(
                icon: Icons.edit_outlined,
                label: '编辑',
                color: Tokens.accent,
                onTap: () => _edit(ctx, ref, false, i)),
            SwipeAction(
                icon: Icons.delete_outline,
                label: '删除',
                color: Tokens.badD10,
                onTap: () => _confirmDelete(ctx, ref,
                    isWalnut: false,
                    id: i.id,
                    name: i.name.isNotEmpty ? i.name : i.type)),
          ],
          child: Stack(children: [
            NeumorphicBox(
              radius: Tokens.rCard,
              padding: const EdgeInsets.fromLTRB(14, 14, 34, 14),
              child: Row(
                children: [
                  CoverThumb(rel: i.coverPath, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.name.isNotEmpty ? i.name : i.type,
                            style: TextStyle(
                                fontSize: Tokens.fsBody,
                                fontWeight: FontWeight.w600,
                                color: Tokens.text)),
                        const SizedBox(height: 4),
                        Text(_sub(i.category, i.variety),
                            style: TextStyle(fontSize: Tokens.fsHint, color: Tokens.muted)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(formatSize(i.sizeMm),
                                style: TextStyle(
                                    fontSize: Tokens.fsLabel, color: Tokens.faint)),
                            const Spacer(),
                            Text(formatPrice(i.price),
                                style: TextStyle(
                                    fontSize: Tokens.fsBody,
                                    color: Tokens.accent,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

  void _openAdd(BuildContext context, WidgetRef ref) {
    final cat = ref.read(collectionCatProvider);
    if (cat == '核桃' || cat == allCat) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AddWalnutSheet(),
          ))
          .then((_) => refreshCollection(ref));
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AddItemSheet(initialType: cat),
          ))
          .then((_) => refreshCollection(ref));
    }
  }
}

/// 子菜单 tab：默认 NeuState.raised 凸起，on 时 color=accentSoft 加深（不用阴影切换），
/// 按压 NeuState.pressed = inSm 凹陷
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
