import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/daos/walnut_dao.dart';
import '../data/daos/item_dao.dart';
import '../data/daos/patina_dao.dart';
import '../data/models/walnut.dart';
import '../data/models/item.dart';
import '../data/models/patina.dart';
import '../data/models/enums.dart';

// 全量列表（增删改后 invalidate 触发刷新）
final walnutsProvider = FutureProvider<List<Walnut>>((ref) => WalnutDao.all());
final itemsProvider = FutureProvider<List<Item>>((ref) => ItemDao.all());

// 按 id 取数（评审意见 P0 第一层）：详情页只持 id，编辑/加走色后 ref.invalidate
// 自动刷新，根除 B4「编辑后看到旧值」。
final walnutByIdProvider =
    FutureProvider.family<Walnut?, int>((ref, id) => WalnutDao.get(id));
final itemByIdProvider =
    FutureProvider.family<Item?, int>((ref, id) => ItemDao.get(id));
// 双参 key：owner_type + owner_id（评审意见 8.4 patina 泛化）
class OwnerRef {
  final String type;
  final int id;
  const OwnerRef(this.type, this.id);
  @override
  bool operator ==(Object other) =>
      other is OwnerRef && other.type == type && other.id == id;
  @override
  int get hashCode => Object.hash(type, id);
}

// 按 owner 取走色（P0 第一层 + 8.4）：详情页传 OwnerRef('walnut', id)
final patinaByOwnerProvider = FutureProvider.family<List<Patina>, OwnerRef>(
    (ref, k) => PatinaDao.byOwner(k.type, k.id));

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
