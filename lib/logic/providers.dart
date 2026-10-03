import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/daos/walnut_dao.dart';
import '../data/daos/item_dao.dart';
import '../data/models/walnut.dart';
import '../data/models/item.dart';

// 全量列表（增删改后 invalidate 触发刷新）
final walnutsProvider = FutureProvider<List<Walnut>>((ref) => WalnutDao.all());
final itemsProvider = FutureProvider<List<Item>>((ref) => ItemDao.all());

// 文玩页一级分类：'核桃' / '其他'
final collectionTabProvider = StateProvider<String>((ref) => '核桃');

// 二级菜单层级（照定稿原型 renderCatMenu）：
// 1 = 只显示一级（核桃 / 其他）；2 = 已点开「其他」，显示二级四类
final collectionMenuLvProvider = StateProvider<int>((ref) => 1);

// 二级选中的类型（仅 tab=='其他' 时生效），'手串' / '吊坠' / '手把件' / '摆件'
// 原型里 curCat 一字复用：一级为 '核桃'，二级为四类之一
final collectionSubProvider = StateProvider<String>((ref) => '手串');

// 三级筛选：核桃=大品类，其他=材质；'' = 全部
final collectionGroupProvider = StateProvider<String>((ref) => '');

// 四级筛选：仅核桃用（品种），依赖已选大品类；'' = 全部
final collectionVarietyProvider = StateProvider<String>((ref) => '');

// 统一刷新：增删改后调用 refreshCollection(ref)
void refreshCollection(WidgetRef ref) {
  ref.invalidate(walnutsProvider);
  ref.invalidate(itemsProvider);
}
