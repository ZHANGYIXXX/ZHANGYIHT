import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
    // V2：Windows 桌面端用 FFI 实现（sqflite 本体仅支持 Android/iOS）
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final base = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(base.path, 'yizhanghe'));
    await dbDir.create(recursive: true); // 确保 yizhanghe/ 存在
    final path = p.join(dbDir.path, 'app.db');
    return openDatabase(
      path,
      // v2：补 item.name —— 其他类此前只有输入框没有列，填了的名称会丢
      version: 2,
      // SQLite 默认关闭外键约束，不打开的话 patina 表的 ON DELETE CASCADE
      // 根本不生效，删核桃会留下孤儿走色记录。
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      // 已装机的旧库必须能平滑升级，否则打开就崩 / 数据读不出来
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE item ADD COLUMN name TEXT NOT NULL DEFAULT ''");
        }
      },
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
            type TEXT, name TEXT, code TEXT, category TEXT, variety TEXT,
            size_mm REAL, strand_type TEXT, weight REAL,
            buy_date TEXT, channel TEXT, merchant TEXT,
            price REAL, cover_path TEXT, remark TEXT
          )
        ''');
      },
    );
  }

  // 导入备份前关闭句柄：覆盖 app.db 文件后由 instance 重新打开读取新库
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
