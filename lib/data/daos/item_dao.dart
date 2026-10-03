import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../models/item.dart';

class ItemDao {
  static Future<int> insert(Item it) async {
    final db = await AppDatabase.instance;
    return db.insert('item', it.toMap());
  }

  static Future<int> update(Item it) async {
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

  static Future<List<Item>> byType(String type) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('item',
        where: 'type = ?', whereArgs: [type], orderBy: 'buy_date DESC');
    return rows.map(Item.fromMap).toList();
  }

  // 同「类型 + 购买日期」已存在的条数（用于编号重名序）
  static Future<int> countSameDay(String type, String buyDate) async {
    final db = await AppDatabase.instance;
    final c = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM item WHERE type = ? AND buy_date = ?',
        [type, buyDate]);
    return (c.first['n'] as int);
  }
}
