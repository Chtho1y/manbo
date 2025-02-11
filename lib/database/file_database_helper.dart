import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:typed_data';

class FileDatabaseHelper {
  static final FileDatabaseHelper instance = FileDatabaseHelper._internal();
  static Database? _database;

  FileDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'file_storage.db'); // 使用独立的数据库文件

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE files (
        id TEXT PRIMARY KEY,
        name TEXT,
        bytes BLOB,
        upload_time TEXT
      )
    ''');
  }

  // 插入文件
  Future<void> insertFile(String id, String name, Uint8List bytes) async {
    final db = await instance.database;
    await db.insert('files', {
      'id': id,
      'name': name,
      'bytes': bytes,
      'upload_time': DateTime.now().toIso8601String(),
    });
  }

  // 获取所有文件
  Future<List<Map<String, dynamic>>> getAllFiles() async {
    final db = await instance.database;
    return await db.query('files');
  }

  // 删除单个文件
  Future<void> deleteFile(String fileId) async {
    final db = await instance.database;
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
  }

  // 更新文件名
  Future<void> updateFileName(String fileId, String newName) async {
    final db = await instance.database;
    await db.update(
      'files',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }
}
