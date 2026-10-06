import '../database.dart';
import '../../logic/codegen.dart';
import '../models/item.dart';

class ItemDao {
  static Future<int> insert(Item it) async {
    final db = await AppDatabase.instance;
    return db.insert('item', it.toMap());
  }

  static Future<int> update(Item it) async {
    if (it.id == null) throw ArgumentError('update 需要已落库的 id');
    final db = await AppDatabase.instance;
    return db.update('item', it.toMap(), where: 'id = ?', whereArgs: [it.id]);
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance;
    return db.delete('item', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Item>> all() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('item', orderBy: 'buy_date DESC');
    return rows.map(Item.fromMap).toList();
  }

  static Future<Item?> get(int id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('item', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  static Future<List<Item>> byType(String type) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('item',
        where: 'type = ?', whereArgs: [type], orderBy: 'buy_date DESC');
    return rows.map(Item.fromMap).toList();
  }

  // 同「类型 + 购买日期」已用过的最大编号序号（删中间记录后新增也不会撞号）
  static Future<int> maxSeqSameDay(String type, String buyDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('item',
        columns: ['code'],
        where: 'type = ? AND buy_date = ?',
        whereArgs: [type, buyDate]);
    return CodeGen.maxSeq(rows.map((r) => (r['code'] as String?) ?? ''));
  }
}
