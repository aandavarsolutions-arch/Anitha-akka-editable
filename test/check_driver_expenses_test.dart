import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Find DB file', () async {
    final home = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\sarav';
    final searchDirs = [
      Directory(p.join(home, 'Documents')),
      Directory(p.join(home, 'AppData', 'Roaming')),
      Directory(p.join(home, 'AppData', 'Local')),
    ];

    List<String> dbFiles = [];
    for (var dir in searchDirs) {
      if (dir.existsSync()) {
        try {
          dir.listSync(recursive: true).forEach((f) {
            if (f.path.endsWith('.db')) {
              dbFiles.add(f.path);
            }
          });
        } catch (_) {}
      }
    }

    print('FOUND DB FILES: $dbFiles');

    for (var path in dbFiles) {
      print('\n==========================================');
      print('EXAMINING DB: $path');
      print('==========================================');
      try {
        final db = await openDatabase(path);
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
        print('Tables: ${tables.map((t) => t['name'])}');

        if (tables.any((t) => t['name'] == 'driver_payments')) {
          final drivers = await db.query('drivers');
          Map<String, String> driverNames = {};
          for (var d in drivers) {
            driverNames[d['id'].toString()] = (d['name'] ?? 'Unknown').toString();
          }

          final payments = await db.query('driver_payments');
          for (var p in payments) {
            final dId = p['driver_id']?.toString() ?? '';
            final dName = driverNames[dId] ?? 'Unknown';
            print('PAYMENT: driver=$dName ($dId) | type=${p['type']} | mode=${p['mode']} | amount=${p['amount']} | date=${p['date']} | id=${p['id']}');
          }
        }
        await db.close();
      } catch (e) {
        print('Error reading $path: $e');
      }
    }
  });
}
