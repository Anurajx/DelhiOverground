import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusDatabaseHelper {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "routes.db");

    final prefs = await SharedPreferences.getInstance();
    final currentDbVersion = prefs.getInt('db_version_key') ?? 0;
    const targetDbVersion = 6; // Increment this whenever the database asset changes

    bool needsCopy = false;
    final exists = await databaseExists(path);
    if (!exists || currentDbVersion < targetDbVersion) {
      needsCopy = true;
    } else {
      try {
        final tempDb = await openDatabase(path, readOnly: true);
        final tables = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='routes'"
        );
        await tempDb.close();
        if (tables.isEmpty) {
          needsCopy = true;
        }
      } catch (e) {
        needsCopy = true;
      }
    }

    if (needsCopy) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // ignore
      }
      final data = await rootBundle.load("assets/routes.db");
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      await prefs.setInt('db_version_key', targetDbVersion);
    }

    _db = await openDatabase(path, readOnly: true);
    return _db!;
  }
}
