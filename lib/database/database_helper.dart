import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'chat_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        role TEXT,
        content TEXT,
        FOREIGN KEY (chat_id) REFERENCES chats (id)
      )
    ''');
  }

  // 插入对话
  Future<void> insertChat(String id, String name) async {
    final db = await instance.database;
    await db.insert('chats', {'id': id, 'name': name});
  }

  // 插入消息
  Future<void> insertMessage(
      String id, String chatId, String role, String content) async {
    final db = await instance.database;
    await db.insert('messages', {
      'id': id,
      'chat_id': chatId,
      'role': role,
      'content': content,
    });
  }

  // 获取所有对话
  Future<List<Map<String, dynamic>>> getChats() async {
    final db = await instance.database;
    return await db.query('chats');
  }

  // 获取某对话的消息
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await instance.database;
    return await db
        .query('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  // 删除某个对话及其相关消息
  Future<void> deleteChat(String chatId) async {
    final db = await instance.database;

    // 先删除关联的消息
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);

    // 再删除对话
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
  }

  // 更新对话名称
  Future<void> updateChatName(String chatId, String newName) async {
    final db = await instance.database;

    await db.update(
      'chats',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }
}
