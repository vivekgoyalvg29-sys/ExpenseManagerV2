import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {

  static Database? _db;

  static Future<Database> get database async {

    if (_db != null) return _db!;

    _db = await initDatabase();

    return _db!;
  }

  static Future<Database> initDatabase() async {

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "expense_manager.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {

        await db.execute('''
        CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          amount REAL,
          date TEXT
        )
        ''');

      },
    );
  }

}
