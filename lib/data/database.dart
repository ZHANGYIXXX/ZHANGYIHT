import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 数据库初始化（单例）
class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final base = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(base.path, 'yizhanghe'));
    await dbDir.create(recursive: true); // 确保 yizhanghe/ 存在
    final path = p.join(dbDir.path, 'app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE walnut (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT, name TEXT, category TEXT, variety TEXT,
            price REAL,
            l_bian REAL, l_du REAL, l_gao REAL,
            r_bian REAL, r_du REAL, r_gao REAL,
            weight REAL, buy_date TEXT, channel TEXT, merchant TEXT,
            full INTEGER, repaired INTEGER, yellow INTEGER,
            remark TEXT, cover_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE patina (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            walnut_id INTEGER,
            date TEXT,
            images TEXT,
            FOREIGN KEY (walnut_id) REFERENCES walnut(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE item (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT, code TEXT, category TEXT, variety TEXT,
            size_mm REAL, strand_type TEXT, weight REAL,
            buy_date TEXT, channel TEXT, merchant TEXT,
            price REAL, cover_path TEXT, remark TEXT
          )
        ''');
      },
    );
  }
}
