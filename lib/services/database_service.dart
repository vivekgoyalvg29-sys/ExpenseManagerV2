import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          amount REAL,
          date TEXT,
          type TEXT,
          account TEXT
        )
        ''');

        await db.execute('''
        CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT,
          icon INTEGER
        )
        ''');

        await db.execute('''
        CREATE TABLE categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT,
          icon INTEGER
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureColumn(db, 'accounts', 'icon INTEGER');
          await _ensureColumn(db, 'categories', 'icon INTEGER');
        }
        if (oldVersion < 3) {
          await _ensureColumn(db, 'transactions', 'account TEXT');
        }
      },
    );
  }

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    final columnName = columnDefinition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((column) => column['name'] == columnName);

    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  }

  static Future<void> insertTransaction(
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
  ) async {
    final db = await database;

    await db.insert(
      "transactions",
      {
        "title": title,
        "amount": amount,
        "date": date.toIso8601String(),
        "type": type,
        "account": account,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return db.query("transactions", orderBy: "date DESC");
  }

  static Future<void> deleteTransaction(int id) async {
    final db = await database;

    await db.delete(
      "transactions",
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> updateTransaction(
    int id,
    String title,
    double amount,
    DateTime date,
    String account,
  ) async {
    final db = await database;

    await db.update(
      "transactions",
      {
        "title": title,
        "amount": amount,
        "date": date.toIso8601String(),
        "account": account,
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> insertAccount(String name, String type, int icon) async {
    final db = await database;

    await db.insert(
      "accounts",
      {
        "name": name,
        "type": type,
        "icon": icon,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;

    return db.query("accounts");
  }

  static Future<void> updateAccount(
    int id,
    String name,
    String type,
    int icon,
  ) async {
    final db = await database;

    await db.update(
      "accounts",
      {
        "name": name,
        "type": type,
        "icon": icon,
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> deleteAccount(int id) async {
    final db = await database;

    await db.delete(
      "accounts",
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> insertCategory(String name, String type, int icon) async {
    final db = await database;

    await db.insert(
      "categories",
      {
        "name": name,
        "type": type,
        "icon": icon,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;

    return db.query("categories");
  }

  static Future<void> updateCategory(
    int id,
    String name,
    String type,
    int icon,
  ) async {
    final db = await database;

    await db.update(
      "categories",
      {
        "name": name,
        "type": type,
        "icon": icon,
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> deleteCategory(int id) async {
    final db = await database;

    await db.delete(
      "categories",
      where: "id = ?",
      whereArgs: [id],
    );
  }


  static Future<bool> accountExists(String name, String type) async {
    final db = await database;

    final result = await db.query(
      'accounts',
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [name.toLowerCase(), type],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  static Future<bool> categoryExists(String name, String type) async {
    final db = await database;

    final result = await db.query(
      'categories',
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [name.toLowerCase(), type],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  static Future<void> insertBudget(
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final db = await database;

    await db.insert(
      "budgets",
      {
        "category": category,
        "amount": amount,
        "month": month,
        "year": year,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;

    return db.query("budgets");
  }

  static Future<void> updateBudget(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final db = await database;

    await db.update(
      "budgets",
      {
        "category": category,
        "amount": amount,
        "month": month,
        "year": year,
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  static Future<void> deleteBudget(int id) async {
    final db = await database;

    await db.delete(
      "budgets",
      where: "id = ?",
      whereArgs: [id],
    );
  }
}
