import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manbo/screens/create_game_screen.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<String> _saveImageToLocalDirectory(String? imagePath) async {
    final defaultImagedirectory = await getApplicationDocumentsDirectory();
    final defaultImagePath = '${defaultImagedirectory.path}/default_image.png';
    try {
      if (imagePath == null || imagePath.isEmpty) {
        return defaultImagePath;
      }
      final directory = await getExternalStorageDirectory();
      final imageName = imagePath.split('/').last;
      final newImagePath = '${directory?.path}/$imageName';
      final sourceFile = File(imagePath);
      if (await sourceFile.exists()) {
        final newImageFile = await sourceFile.copy(newImagePath);
        return newImageFile.path;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('该图片不受支持，使用默认图片。')),
        );
        return defaultImagePath;
      }
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return defaultImagePath;
    }
  }

  void _upsertGame({
    int? index,
    required String title,
    required String description,
    required String htmlContent,
    required String imagePath,
  }) async {
    final newPath = await _saveImageToLocalDirectory(imagePath);
    if (index != null) {
      final oldImagePath = games[index]['imagePath'];
      if (oldImagePath != null && oldImagePath != newPath) {
        final oldImageFile = File(oldImagePath);
        if (await oldImageFile.exists()) {
          try {
            await oldImageFile.delete();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除旧图片文件时出错: $e')),
            );
          }
        }
      }
    }
    setState(() {
      final game = {
        'title': title,
        'description': description,
        'htmlContent': htmlContent,
        'imagePath': newPath,
      };
      if (index != null) {
        games[index] = game;
      } else {
        games.add(game);
      }
    });
    _saveGames();
  }

  void _deleteGame(int index) {
    final imagePath = games[index]['imagePath'];
    if (imagePath != null && File(imagePath).existsSync()) {
      File(imagePath).deleteSync();
    }
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
              _upsertGame(
                index: index,
                title: title,
                description: description,
                htmlContent: htmlContent,
                imagePath: imagePath,
              );
            },
            initialData: game, // 传递初始数据
          ),
        ),
      );
    } else if (action == 'delete') {
      _deleteGame(index);
      _loadGames();
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
                      _upsertGame(
                        title: title,
                        description: description,
                        htmlContent: htmlContent,
                        imagePath: imagePath,
                      );
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
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              )
                            : (File(game['imagePath']).existsSync()
                                ? Image.file(
                                    File(game['imagePath']),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  )),
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
