import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../models/patina.dart';

class PatinaDao {
  static Future<int> insert(Patina p) async {
    final db = await AppDatabase.instance;
    return db.insert('patina', p.toMap());
  }

  static Future<List<Patina>> byWalnut(int walnutId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('patina',
        where: 'walnut_id = ?', whereArgs: [walnutId], orderBy: 'date DESC');
    return rows.map(Patina.fromMap).toList();
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance;
    return db.delete('patina', where: 'id = ?', whereArgs: [id]);
  }

  /// 删某件核桃的全部走色记录。
  /// 建表时虽写了 ON DELETE CASCADE，但 SQLite 默认 foreign_keys=OFF，
  /// 级联不会生效，必须显式删，否则留下孤儿行。
  static Future<int> deleteByWalnut(int walnutId) async {
    final db = await AppDatabase.instance;
    return db.delete('patina', where: 'walnut_id = ?', whereArgs: [walnutId]);
  }
}
