import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {

  static Database? _db;

  Future<Database> get db async {

    if (_db != null) return _db!;

    _db = await initDB();

    return _db!;
  }

  Future<Database> initDB() async {

    String path = join(await getDatabasesPath(), 'expense.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {

        await db.execute('''
        CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT
        )
        ''');

        await db.execute('''
        CREATE TABLE categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT
        )
        ''');

        await db.execute('''
        CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT,
          account TEXT,
          category TEXT,
          comment TEXT,
          amount REAL,
          date TEXT
        )
        ''');

        await db.execute('''
        CREATE TABLE budgets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT,
  amount REAL,
  month INTEGER,
  year INTEGER
)
        ''');
      },
    );
  }
}
