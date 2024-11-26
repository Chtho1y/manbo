import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
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

  Future<String> _saveImageToLocalDirectory(String imagePath) async {
    try {
      final directory = await getExternalStorageDirectory();
      final imageName = imagePath.split('/').last;
      final newImagePath = '${directory?.path}/$imageName';
      final sourceFile = File(imagePath);
      if (await sourceFile.exists()) {
        final newImageFile = await sourceFile.copy(newImagePath);
        return newImageFile.path;
      } else {
        return '';
      }
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return '';
    }
  }

  void _upsertGame({
    int? index,
    required String title,
    required String description,
    required String htmlContent,
    required String imagePath,
    bool isGenerating = false,
    bool isFailed = false,
  }) async {
    String newPath;
    double aspectRatio = 16 / 9; // 默认宽高比

    try {
      final decodedImage =
          await decodeImageFromList(File(imagePath).readAsBytesSync());
      aspectRatio = decodedImage.width / decodedImage.height;
    } catch (e) {
      debugPrint('获取图片宽高比失败: $e');
    }

    if (index != null) {
      final oldImagePath = games[index]['imagePath'];
      if (oldImagePath != null && oldImagePath == imagePath) {
        newPath = oldImagePath;
      } else {
        newPath = await _saveImageToLocalDirectory(imagePath);
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
    } else {
      newPath = await _saveImageToLocalDirectory(imagePath);
    }

    setState(() {
      final game = {
        'title': title,
        'description': description,
        'htmlContent': htmlContent,
        'imagePath': newPath,
        'isGenerating': isGenerating,
        'isFailed': isFailed,
        'aspectRatio': aspectRatio,
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
    final game = games[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (game['isFailed'] ?? false)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () {
                  Navigator.pop(context, 'regenerate');
                },
              ),
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

    if (action == 'regenerate') {
      final failedGame = games[index];
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
                isGenerating: true,
              );
            },
            initialData: failedGame,
          ),
        ),
      );
    } else if (action == 'edit') {
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
            initialData: game,
          ),
        ),
      );
    } else if (action == 'delete') {
      _deleteGame(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
