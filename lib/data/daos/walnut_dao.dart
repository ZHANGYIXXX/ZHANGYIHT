import '../database.dart';
import '../../logic/codegen.dart';
import '../models/walnut.dart';

class WalnutDao {
  static Future<int> insert(Walnut w) async {
    final db = await AppDatabase.instance;
    return db.insert('walnut', w.toMap());
  }

  static Future<int> update(Walnut w) async {
    final db = await AppDatabase.instance;
    return db.update('walnut', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
  }

  static Future<int> delete(int id) async {
    final db = await AppDatabase.instance;
    return db.delete('walnut', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Walnut>> all() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('walnut', orderBy: 'buy_date DESC');
    return rows.map(Walnut.fromMap).toList();
  }

  static Future<Walnut?> get(int id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('walnut', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Walnut.fromMap(rows.first);
  }

  // 同「购买日期」已用过的最大编号序号（删中间记录后新增也不会撞号）
  static Future<int> maxSeqSameDay(String buyDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('walnut',
        columns: ['code'], where: 'buy_date = ?', whereArgs: [buyDate]);
    return CodeGen.maxSeq(rows.map((r) => (r['code'] as String?) ?? ''));
  }
}
