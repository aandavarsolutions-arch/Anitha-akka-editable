import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<String> _getDbPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(join(docsDir.path, 'JarvisData_Customer2'));
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    return join(dbFolder.path, 'jarvis_customer2_data.db');
  }

  Future<Database> _initDB() async {
    final path = await _getDbPath();
    
    final db = await openDatabase(
      path,
      version: 49,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Dynamic column additions for backward compatibility with existing databases
    try { await db.execute('ALTER TABLE drivers ADD COLUMN advance_amount TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE drivers ADD COLUMN license_expiry TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE drivers ADD COLUMN pause_salary INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE vehicle_registry ADD COLUMN insurance_expiry TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE vehicle_registry ADD COLUMN fc_expiry TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE vehicle_registry ADD COLUMN puc_expiry TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE vehicles ADD COLUMN driver TEXT'); } catch (_) {}
    
    // Ensure all site_expenses columns exist on client databases
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN site TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN supplier TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN vehicle_no TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN quantity TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN unit TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN liters TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN rate TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN material_name TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN paid TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE site_expenses ADD COLUMN status TEXT'); } catch (_) {}

    // Ensure fuel_tanks & fuel_issues tables exist
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fuel_tanks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          current_liters REAL DEFAULT 0.0,
          capacity_liters REAL DEFAULT 5000.0,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fuel_issues (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          tank_id INTEGER,
          vehicle_number TEXT,
          vehicle_type TEXT,
          liters REAL,
          driver_name TEXT,
          odometer_hours TEXT,
          notes TEXT
        )
      ''');
    } catch (_) {}

    return db;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 49) {
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN liters TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN rate TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN quantity TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN unit TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN material_name TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN supplier TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN vehicle_no TEXT'); } catch (_) {}
    }
    if (oldVersion < 46) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fuel_tanks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            current_liters REAL DEFAULT 0.0,
            capacity_liters REAL DEFAULT 5000.0,
            notes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fuel_issues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            tank_id INTEGER,
            vehicle_number TEXT,
            vehicle_type TEXT,
            liters REAL,
            driver_name TEXT,
            odometer_hours TEXT,
            notes TEXT
          )
        ''');
        final tanks = await db.query('fuel_tanks');
        if (tanks.isEmpty) {
          await db.insert('fuel_tanks', {
            'name': 'Main Storage Tank',
            'current_liters': 0.0,
            'capacity_liters': 5000.0,
            'notes': 'Default Company Bulk Fuel Storage'
          });
        }
      } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN liters TEXT'); } catch (_) {}
    }
    if (oldVersion < 45) {
      try { await db.execute('ALTER TABLE vehicles ADD COLUMN bill_no TEXT'); } catch (_) {}
    }
    if (oldVersion < 44) {
      try { await db.execute('ALTER TABLE vehicles ADD COLUMN batta TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE vehicles ADD COLUMN batta_amount TEXT'); } catch (_) {}
    }
    if (oldVersion < 43) {
      try { await db.execute('ALTER TABLE driver_payments ADD COLUMN mode TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE driver_payments ADD COLUMN time TEXT'); } catch (_) {}
    }
    if (oldVersion < 42) {
      try { await db.execute('ALTER TABLE driver_attendance ADD COLUMN earnings TEXT'); } catch (_) {}
    }
    if (oldVersion < 41) {
      try { await db.execute('ALTER TABLE driver_payments ADD COLUMN mode TEXT'); } catch (_) {}
    }
    if (oldVersion < 40) {
      try { await db.execute('ALTER TABLE drivers ADD COLUMN emp_type TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN salary TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN advance_amount TEXT'); } catch (_) {}
    }
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE bills ADD COLUMN paid TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE bill_payments (
          id TEXT PRIMARY KEY,
          bill_id TEXT,
          amount TEXT,
          date TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('CREATE TABLE labour_payments (id TEXT PRIMARY KEY, labour_id TEXT, amount TEXT, date TEXT)');
      await db.execute('CREATE TABLE vehicle_payments (id TEXT PRIMARY KEY, vehicle_id TEXT, amount TEXT, date TEXT)');
      await db.execute('CREATE TABLE supplier_payments (id TEXT PRIMARY KEY, supplier_id TEXT, amount TEXT, date TEXT)');
      await db.execute('CREATE TABLE driver_payments (id TEXT PRIMARY KEY, driver_id TEXT, amount TEXT, date TEXT, type TEXT)');
      await db.execute('CREATE TABLE income_payments (id TEXT PRIMARY KEY, income_id TEXT, amount TEXT, date TEXT)');
    }
    if (oldVersion < 5) {
      // Add date column to tables that were missing it
      await db.execute('ALTER TABLE site_income ADD COLUMN date TEXT');
      await db.execute('ALTER TABLE labour ADD COLUMN date TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN date TEXT');
      await db.execute('ALTER TABLE suppliers ADD COLUMN date TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN date TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE site_income ADD COLUMN status TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE site_income ADD COLUMN work_type TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE site_expenses ADD COLUMN site TEXT');
    }
    if (oldVersion < 9) {
      // Users table for authentication
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password TEXT,
          role TEXT
        )
      ''');
      // Default admin user
      await db.execute("INSERT INTO users (username, password, role) VALUES ('admin', 'admin', 'admin')");

      // Settings table for app configuration
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN isRentedOut INTEGER');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE vehicle_registry (
          id TEXT PRIMARY KEY,
          number TEXT,
          type TEXT,
          rate_type TEXT,
          rate TEXT
        )
      ''');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN site TEXT');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE drivers ADD COLUMN site TEXT');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE site_expenses ADD COLUMN supplier TEXT');
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE suppliers ADD COLUMN last_purchase TEXT');
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE site_expenses ADD COLUMN vehicle_no TEXT');
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE drivers ADD COLUMN contact TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN paid TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN balance TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN vehicle_id TEXT');
    }
    if (oldVersion < 18) {
       // Check if column exists or catch error (as v4 created it already for new DBs, but upgraders need it)
       try { await db.execute('ALTER TABLE driver_payments ADD COLUMN type TEXT'); } catch (_) {}
    }
    if (oldVersion < 20) {
      await db.execute('ALTER TABLE site_expenses ADD COLUMN paid TEXT');
      await db.execute('ALTER TABLE site_expenses ADD COLUMN status TEXT');
    }
    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE site_expense_payments (
          id TEXT PRIMARY KEY,
          expense_id TEXT,
          amount TEXT,
          date TEXT
        )
      ''');
    }
    if (oldVersion < 22) {
      await db.execute('ALTER TABLE site_income ADD COLUMN estimate TEXT');
    }
    if (oldVersion < 23) {
      await db.execute('ALTER TABLE suppliers ADD COLUMN contact TEXT');
    }
    if (oldVersion < 24) {
      await db.execute('ALTER TABLE vehicle_registry ADD COLUMN rate_hour TEXT');
      await db.execute('ALTER TABLE vehicle_registry ADD COLUMN rate_day TEXT');
      await db.execute('ALTER TABLE vehicle_registry ADD COLUMN rate_trip TEXT');
      
      // Migrate existing rates
      final registries = await db.query('vehicle_registry');
      for (var reg in registries) {
        String type = reg['rate_type'].toString();
        String rate = reg['rate'].toString();
        if (type == 'Hour') {
          await db.update('vehicle_registry', {'rate_hour': rate}, where: 'id = ?', whereArgs: [reg['id']]);
        } else if (type == 'Day') {
          await db.update('vehicle_registry', {'rate_day': rate}, where: 'id = ?', whereArgs: [reg['id']]);
        } else if (type == 'Trip') {
          await db.update('vehicle_registry', {'rate_trip': rate}, where: 'id = ?', whereArgs: [reg['id']]);
        }
      }
    }
    if (oldVersion < 25) {
      await db.execute('ALTER TABLE vehicle_registry ADD COLUMN rates TEXT'); // For JSON storage of dynamic rates
      
      // Migrate existing rate columns to JSON
      final registries = await db.query('vehicle_registry');
      for (var reg in registries) {
        Map<String, String> ratesMap = {};
        if (reg['rate_hour']?.toString().isNotEmpty ?? false) ratesMap['Hour'] = reg['rate_hour'].toString();
        if (reg['rate_day']?.toString().isNotEmpty ?? false) ratesMap['Day'] = reg['rate_day'].toString();
        if (reg['rate_trip']?.toString().isNotEmpty ?? false) ratesMap['Trip'] = reg['rate_trip'].toString();
        
        if (ratesMap.isNotEmpty) {
          await db.update('vehicle_registry', {'rates': jsonEncode(ratesMap)}, where: 'id = ?', whereArgs: [reg['id']]);
        }
      }
    }
    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          name TEXT,
          phone TEXT,
          address TEXT,
          balance TEXT,
          date TEXT
        )
      ''');
    }
    if (oldVersion < 27) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN rate TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN duration TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN rate_type TEXT');
    }
    if (oldVersion < 28) {
      await db.execute('''
        CREATE TABLE driver_attendance (
          id TEXT PRIMARY KEY,
          driver_id TEXT,
          date TEXT,
          status TEXT,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 29) {
      await db.execute('''
        CREATE TABLE supplier_materials (
          id TEXT PRIMARY KEY,
          supplier_id TEXT,
          material_name TEXT,
          buy_price TEXT,
          sell_price TEXT,
          unit TEXT,
          date TEXT
        )
      ''');
    }
    if (oldVersion < 30) {
      await db.execute('ALTER TABLE site_expenses ADD COLUMN quantity TEXT');
      await db.execute('ALTER TABLE site_expenses ADD COLUMN unit TEXT');
      await db.execute('ALTER TABLE site_expenses ADD COLUMN material_name TEXT');
    }
    if (oldVersion < 31) {
       await db.execute('ALTER TABLE vehicles ADD COLUMN supplier TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN material_name TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN quantity TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN unit TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN material_amount TEXT');
    }
    if (oldVersion < 32) {
       await db.execute('ALTER TABLE vehicles ADD COLUMN customer TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN rent_amount TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN unit_price TEXT');
       await db.execute('ALTER TABLE vehicles ADD COLUMN buy_price TEXT');
    }
    if (oldVersion < 33) {
      // Repair Schema for Reset/Broken Installs
      try { await db.execute('ALTER TABLE drivers ADD COLUMN site TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN contact TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN paid TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN balance TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE drivers ADD COLUMN vehicle_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN supplier TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN vehicle_no TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN quantity TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN unit TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE site_expenses ADD COLUMN material_name TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE suppliers ADD COLUMN last_purchase TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE driver_payments ADD COLUMN type TEXT'); } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS driver_attendance (
          id TEXT PRIMARY KEY,
          driver_id TEXT,
          date TEXT,
          status TEXT,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 34) {
      // Force Fix for driver_payments missing column if v33 had empty table
      try { await db.execute('ALTER TABLE driver_payments ADD COLUMN type TEXT'); } catch (_) {}
    }
    if (oldVersion < 35) {
      try { await db.execute('ALTER TABLE vehicles ADD COLUMN manual_desc TEXT'); } catch (_) {}
    }
    if (oldVersion < 36) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_payments (
          id TEXT PRIMARY KEY,
          customer_name TEXT,
          amount TEXT,
          date TEXT,
          notes TEXT
        )
      ''');
      try { await db.execute('ALTER TABLE driver_attendance ADD COLUMN status2 TEXT'); } catch (_) {}
    }
    if (oldVersion < 37) {
       // REQ 3: Column for Vehicles
       try { await db.execute('ALTER TABLE vehicles ADD COLUMN isOwnSite INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 38) {
       // Ensure customer_payments exists for everyone
       await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_payments (
          id TEXT PRIMARY KEY,
          customer_name TEXT,
          amount TEXT,
          date TEXT,
          notes TEXT
        )
      ''');
      // Ensure status2 exists for everyone
      try { await db.execute('ALTER TABLE driver_attendance ADD COLUMN status2 TEXT'); } catch (_) {}
    }
    if (oldVersion < 39) {
       try { await db.execute('ALTER TABLE customer_payments ADD COLUMN type TEXT'); } catch (_) {}
    }
    if (oldVersion < 48) {
       try { await db.execute('ALTER TABLE supplier_payments ADD COLUMN type TEXT'); } catch (_) {}
       try { await db.execute('ALTER TABLE supplier_payments ADD COLUMN notes TEXT'); } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        role TEXT
      )
    ''');
    await db.execute("INSERT INTO users (username, password, role) VALUES ('admin', 'admin', 'admin')");

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Default Branding & Biz Settings
    await db.execute("INSERT INTO settings (key, value) VALUES ('dev_name', 'Aandavar Solutions')");
    await db.execute("INSERT INTO settings (key, value) VALUES ('dev_contact', '+91 99440 27958')");
    await db.execute("INSERT INTO settings (key, value) VALUES ('dev_email', 'aandavarsolutions@gmail.com')");
    await db.execute("INSERT INTO settings (key, value) VALUES ('business_name', 'Aandavar Solutions')");

    // Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        subtitle TEXT,
        amount TEXT,
        date TEXT,
        status TEXT,
        isExpense INTEGER
      )
    ''');
    
    // Bill Payments
    await db.execute('''
      CREATE TABLE bill_payments (
        id TEXT PRIMARY KEY,
        bill_id TEXT,
        amount TEXT,
        date TEXT
      )
    ''');

     // New Payment Tables
    await db.execute('CREATE TABLE labour_payments (id TEXT PRIMARY KEY, labour_id TEXT, amount TEXT, date TEXT)');
    await db.execute('CREATE TABLE vehicle_payments (id TEXT PRIMARY KEY, vehicle_id TEXT, amount TEXT, date TEXT)');
    await db.execute('CREATE TABLE supplier_payments (id TEXT PRIMARY KEY, supplier_id TEXT, amount TEXT, date TEXT)');
    await db.execute('CREATE TABLE driver_payments (id TEXT PRIMARY KEY, driver_id TEXT, amount TEXT, date TEXT, time TEXT, type TEXT, mode TEXT)');
    await db.execute('CREATE TABLE income_payments (id TEXT PRIMARY KEY, income_id TEXT, amount TEXT, date TEXT)');

    // Bills
    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        site TEXT,
        date TEXT,
        amount TEXT,
        paid TEXT,
        status TEXT
      )
    ''');

    // Labour
    await db.execute('''
      CREATE TABLE labour (
        id TEXT PRIMARY KEY,
        name TEXT,
        site TEXT,
        type TEXT,
        advance TEXT,
        balance TEXT,
        date TEXT
      )
    ''');

    // Vehicles
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        number TEXT,
        type TEXT,
        isOwn INTEGER,
        isRentedOut INTEGER,
        site TEXT,
        total TEXT,
        paid TEXT,
        balance TEXT,
        status TEXT,
        date TEXT,
        rate TEXT,
        duration TEXT,
        rate_type TEXT,
        supplier TEXT,
        material_name TEXT,
        quantity TEXT,
        unit TEXT,
        material_amount TEXT,
        customer TEXT,
        rent_amount TEXT,
        unit_price TEXT,
        buy_price TEXT,
        manual_desc TEXT,
        batta TEXT,
        batta_amount TEXT,
        bill_no TEXT,
        isOwnSite INTEGER DEFAULT 0
      )
    ''');

    // Suppliers
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT,
        contact TEXT,
        material TEXT,
        total TEXT,
        paid TEXT,
        balance TEXT,
        date TEXT,
        last_purchase TEXT
      )
    ''');

    // Drivers
    await db.execute('''
      CREATE TABLE drivers (
        id TEXT PRIMARY KEY,
        name TEXT,
        vehicle TEXT,
        type TEXT,
        earnings TEXT,
        status TEXT,
        date TEXT,
        site TEXT,
        contact TEXT,
        paid TEXT,
        balance TEXT,
        vehicle_id TEXT,
        emp_type TEXT,
        salary TEXT
      )
    ''');

    // Site Income
    await db.execute('''
      CREATE TABLE site_income (
        id TEXT PRIMARY KEY,
        site TEXT,
        client TEXT,
        estimate TEXT,
        received TEXT,
        pending TEXT,
        profit TEXT,
        isProfit INTEGER,
        date TEXT,
        status TEXT,
        work_type TEXT
      )
    ''');

    // Site Expenses
    await db.execute('''
      CREATE TABLE site_expenses (
        id TEXT PRIMARY KEY,
        title TEXT,
        category TEXT,
        amount TEXT,
        paid TEXT,
        status TEXT,
        date TEXT,
        site TEXT,
        supplier TEXT,
        vehicle_no TEXT,
        quantity TEXT,
        unit TEXT,
        liters TEXT,
        rate TEXT,
        material_name TEXT
      )
    ''');

    // Vehicle Registry
    await db.execute('''
      CREATE TABLE vehicle_registry (
        id TEXT PRIMARY KEY,
        number TEXT,
        type TEXT,
        rate_type TEXT,
        rate TEXT,
        rate_hour TEXT,
        rate_day TEXT,
        rate_trip TEXT,
        rates TEXT
      )
    ''');

    // Customers (for Vehicle Rentals)
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        address TEXT,
        balance TEXT,
        date TEXT
      )
    ''');

    // Site Expense Payments
    await db.execute('''
      CREATE TABLE site_expense_payments (
        id TEXT PRIMARY KEY,
        expense_id TEXT,
        amount TEXT,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE supplier_materials (
        id TEXT PRIMARY KEY,
        supplier_id TEXT,
        material_name TEXT,
        buy_price TEXT,
        sell_price TEXT,
        unit TEXT,
        date TEXT
      )
    ''');
    
    // Driver Attendance
    await db.execute('''
      CREATE TABLE driver_attendance (
        id TEXT PRIMARY KEY,
        driver_id TEXT,
        date TEXT,
        status TEXT,
        status2 TEXT,
        notes TEXT,
        earnings TEXT
      )
    ''');

    // Customer Payments
    await db.execute('''
      CREATE TABLE customer_payments (
        id TEXT PRIMARY KEY,
        customer_name TEXT,
        amount TEXT,
        date TEXT,
        notes TEXT,
        type TEXT
      )
    ''');

  }

  Future<String> getDbFilePath() async {
    return await _getDbPath();
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('bills');
      await txn.delete('labour');
      await txn.delete('vehicles');
      await txn.delete('suppliers');
      await txn.delete('drivers');
      await txn.delete('site_income');
      await txn.delete('site_expenses');
      await txn.delete('vehicle_registry');
      await txn.delete('customers');
      
      // Payments & Sub-tables
      await txn.delete('bill_payments');
      await txn.delete('labour_payments');
      await txn.delete('vehicle_payments');
      await txn.delete('supplier_payments');
      await txn.delete('driver_payments');
      await txn.delete('income_payments');
      await txn.delete('site_expense_payments');
      await txn.delete('supplier_materials');
      await txn.delete('driver_attendance');
      await txn.delete('customer_payments');
      try {
        await txn.delete('fuel_issues');
        await txn.update('fuel_tanks', {'current_liters': 0.0});
      } catch (_) {}
      
      // NOTE: We DO NOT delete 'users' or 'settings' to preserve login and config.
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }

  Future<void> nukeDatabase() async {
     // 1. Close connections
     await close();

     // 2. Delete the file
     String path = await _getDbPath();
     await deleteDatabase(path);
  }

  // Generic Helpers
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<Object?>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(String table, Map<String, dynamic> data, String idColumn, dynamic idValue) async {
    final db = await database;
    return await db.update(table, data, where: '$idColumn = ?', whereArgs: [idValue]);
  }

  Future<int> delete(String table, String idColumn, dynamic idValue) async {
    final db = await database;
    final args = idValue is List ? idValue : [idValue];
    return await db.delete(table, where: '$idColumn = ?', whereArgs: args);
  }

  /// Delete with a raw WHERE clause. e.g. rawDelete('fuel_issues', 'id = ?', [5])
  Future<int> rawDelete(String table, String where, List<Object?> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
}

