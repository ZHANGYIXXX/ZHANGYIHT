import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/daos/walnut_dao.dart';
import '../data/daos/item_dao.dart';
import '../data/models/walnut.dart';
import '../data/models/item.dart';
import '../data/models/enums.dart';

// 全量列表（增删改后 invalidate 触发刷新）
final walnutsProvider = FutureProvider<List<Walnut>>((ref) => WalnutDao.all());
final itemsProvider = FutureProvider<List<Item>>((ref) => ItemDao.all());

// 一级分类 tab：'全部' / '核桃' / '手串' / '吊坠' / '手把件' / '摆件'
final collectionCatProvider = StateProvider<String>((ref) => allCat);

// 手填品类筛选（二级下拉）：'' = 全部品类
final collectionFilterProvider = StateProvider<String>((ref) => '');

// 搜索关键字（名称 / 品类），由搜索框实时写入
final collectionSearchProvider = StateProvider<String>((ref) => '');

// 统一刷新：增删改后调用 refreshCollection(ref)
void refreshCollection(WidgetRef ref) {
  ref.invalidate(walnutsProvider);
  ref.invalidate(itemsProvider);
}
