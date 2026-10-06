import '../data/daos/walnut_dao.dart';
import '../data/daos/item_dao.dart';
import '../data/daos/patina_dao.dart';
import '../data/image_store.dart';

/// 删除藏品：库记录 + 原图目录，一次清干净。
/// 之前列表页删除只删了数据库行，图片目录一直留在磁盘上（占空间且永不释放），
/// 走色记录也因 SQLite 未开外键而变成孤儿行 —— 统一收敛到这里。
class DeleteHelper {
  /// 删核桃：走色记录 → 走色图目录（历史布局 patina/{id} + 新布局 patina/walnut/{id}）
  /// → 封面图目录 → 主记录
  static Future<void> walnut(int id) async {
    await PatinaDao.deleteByOwner('walnut', id);
    await ImageStore.deleteDir('patina', id); // 历史布局 images/patina/{id}
    await ImageStore.deletePatinaDir('walnut', id); // 新布局 images/patina/walnut/{id}
    await ImageStore.deleteDir('walnut', id);
    await WalnutDao.delete(id);
  }

  /// 删其他类：走色图目录（若已接入）→ 封面图目录 → 主记录
  static Future<void> item(int id) async {
    await PatinaDao.deleteByOwner('item', id);
    await ImageStore.deletePatinaDir('item', id); // 未来接入走色时隔离，不撞核桃
    await ImageStore.deleteDir('item', id);
    await ItemDao.delete(id);
  }
}
