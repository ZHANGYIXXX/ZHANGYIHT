import '../database.dart';
import '../models/patina.dart';

class PatinaDao {
  static Future<int> insert(Patina p) async {
    final db = await AppDatabase.instance;
    return db.insert('patina', p.toMap());
  }

  /// 按 owner 取走色（评审意见 8.4 泛化）：owner_type + owner_id
  static Future<List<Patina>> byOwner(String type, int ownerId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('patina',
        where: 'owner_type = ? AND owner_id = ?',
        whereArgs: [type, ownerId],
        orderBy: 'date DESC');
    return rows.map(Patina.fromMap).toList();
  }

  /// 按核桃便捷封装（历史调用兼容）
  static Future<List<Patina>> byWalnut(int walnutId) =>
      byOwner('walnut', walnutId);

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance;
    return db.delete('patina', where: 'id = ?', whereArgs: [id]);
  }

  /// 按 owner 删走色（评审意见 8.4 泛化）
  static Future<int> deleteByOwner(String type, int ownerId) async {
    final db = await AppDatabase.instance;
    return db.delete('patina',
        where: 'owner_type = ? AND owner_id = ?', whereArgs: [type, ownerId]);
  }

  /// 按核桃便捷封装（历史调用兼容）
  static Future<int> deleteByWalnut(int walnutId) =>
      deleteByOwner('walnut', walnutId);
}
