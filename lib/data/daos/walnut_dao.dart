import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../../logic/codegen.dart';
import '../models/walnut.dart';

class WalnutDao {
  static Future<int> insert(Walnut w) async {
    final db = await AppDatabase.instance;
    return db.insert('walnut', w.toMap());
  }

  static Future<int> update(Walnut w) async {
    if (w.id == null) throw ArgumentError('update 需要已落库的 id');
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

  /// 事务版本：供 Seed 等批量导入使用，与 insertTxn 配对。
  static Future<int> maxSeqSameDayTxn(Transaction txn, String buyDate) async {
    final rows = await txn.query('walnut',
        columns: ['code'], where: 'buy_date = ?', whereArgs: [buyDate]);
    return CodeGen.maxSeq(rows.map((r) => (r['code'] as String?) ?? ''));
  }

  /// 事务版本：配合 maxSeqSameDayTxn 使用，保证批量写入原子性。
  static Future<int> insertTxn(Transaction txn, Walnut w) =>
      txn.insert('walnut', w.toMap());
}
