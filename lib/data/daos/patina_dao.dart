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
}
