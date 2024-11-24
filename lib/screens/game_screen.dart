import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manbo/screens/create_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/webview_page.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Map<String, dynamic>> games = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final String? gamesJson = prefs.getString('games');
    if (gamesJson != null) {
      setState(() {
        games = List<Map<String, dynamic>>.from(json.decode(gamesJson));
      });
    }
  }

  Future<void> _saveGames() async {
    final prefs = await SharedPreferences.getInstance();
    final String gamesJson = json.encode(games);
    await prefs.setString('games', gamesJson);
  }

  void _addGame(
      String title, String htmlContent, String description, String imagePath) {
    setState(() {
      games.add({
        'title': title,
        'description': description,
        'htmlContent': htmlContent,
        'imagePath': imagePath,
      });
    });
    _saveGames();
  }

  void _editGame(int index, String title, String description,
      String htmlContent, String imagePath) {
    setState(() {
      games[index] = {
        'title': title,
        'description': description,
        'htmlContent': htmlContent,
        'imagePath': imagePath,
      };
    });
    _saveGames();
  }

  void _deleteGame(int index) {
    setState(() {
      games.removeAt(index);
    });
    _saveGames();
  }

  Future<void> _showBottomSheet(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('修改'),
              onTap: () {
                Navigator.pop(context, 'edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(context, 'delete');
              },
            ),
          ],
        );
      },
    );

    if (action == 'edit') {
      final game = games[index];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateGameScreen(
            onGameCreated: (title, description, htmlContent, imagePath) {
              _editGame(index, title, description, htmlContent, imagePath);
            },
            initialData: game, // 传递初始数据
          ),
        ),
      );
    } else if (action == 'delete') {
      _deleteGame(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏制作'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGameScreen(
                    onGameCreated:
                        (title, description, htmlContent, imagePath) {
                      _addGame(title, description, htmlContent, imagePath);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 8.0, horizontal: 16.0), // 水平和垂直间距
            child: Card(
              elevation: 4.0, // 添加一些阴影效果
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0), // 圆角卡片
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 固定高度的图片显示区域，等比缩放图片
                  if (game['imagePath'] != null && game['imagePath'].isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        topRight: Radius.circular(12.0),
                      ), // 上部圆角
                      child: AspectRatio(
                        aspectRatio: 16 / 9, // 固定宽高比为16:9
                        child: kIsWeb
                            ? Image.network(
                                game['imagePath'],
                                fit: BoxFit.cover, // 保持等比缩放，裁剪溢出部分
                              )
                            : Image.file(
                                File(game['imagePath']),
                                fit: BoxFit.cover, // 保持等比缩放，裁剪溢出部分
                              ),
                      ),
                    ),
                  ListTile(
                    title: Text(
                      game['title'],
                      style: const TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewPage.fromHtml(
                            htmlContent: game['htmlContent'],
                            title: game['title'],
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _showBottomSheet(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
