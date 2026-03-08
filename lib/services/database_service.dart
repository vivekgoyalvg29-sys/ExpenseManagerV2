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

        await db.execute('''
        CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT
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

  // TRANSACTIONS

  static Future<void> insertTransaction(
    String title,
    double amount,
    DateTime date,
  ) async {

    final db = await database;

    await db.insert(
      "transactions",
      {
        "title": title,
        "amount": amount,
        "date": date.toIso8601String(),
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {

    final db = await database;

    return await db.query(
      "transactions",
      orderBy: "date DESC",
    );
  }

  // ACCOUNTS

  static Future<void> insertAccount(String name, String type) async {

    final db = await database;

    await db.insert("accounts", {
      "name": name,
      "type": type
    });
  }

  static Future<List<Map<String, dynamic>>> getAccounts() async {

    final db = await database;

    return await db.query("accounts");
  }

  // CATEGORIES

  static Future<void> insertCategory(String name, String type) async {

    final db = await database;

    await db.insert("categories", {
      "name": name,
      "type": type
    });
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {

    final db = await database;

    return await db.query("categories");
  }

  // BUDGETS

  static Future<void> insertBudget(
      String category,
      double amount,
      int month,
      int year) async {

    final db = await database;

    await db.insert("budgets", {
      "category": category,
      "amount": amount,
      "month": month,
      "year": year
    });
  }

  static Future<List<Map<String, dynamic>>> getBudgets() async {

    final db = await database;

    return await db.query("budgets");
  }

}
