import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
        'isGenerating': htmlContent.isEmpty, // 判断是否正在生成
        'isFailed': isFailed, // 失败状态字段
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

  Future<Size> _getImageSize(String imagePath) async {
    try {
      final image = File(imagePath);
      final decodedImage = await decodeImageFromList(image.readAsBytesSync());
      return Size(
          decodedImage.width.toDouble(), decodedImage.height.toDouble());
    } catch (e) {
      // debugPrint('获取图片尺寸失败: $e');
      return const Size(16.0, 9.0); // 默认宽高比为16:9
    }
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
            initialIndex: index, // 传递当前游戏索引
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
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer(); // 调用HomeScreen的左侧菜单
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.plus),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGameScreen(
                    onGameCreated:
                        (title, description, htmlContent, imagePath) {
                      // 检查是否已经存在该任务，避免重复添加
                      final existingIndex = games.indexWhere((game) =>
                          game['title'] == title &&
                          game['isGenerating'] == true);

                      if (existingIndex == -1) {
                        _upsertGame(
                          title: title,
                          description: description,
                          htmlContent: htmlContent,
                          imagePath: imagePath,
                          isGenerating: htmlContent.isEmpty,
                          isFailed: false,
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            final isGenerating = game['isGenerating'] ?? false;
            final isFailed = game['isFailed'] ?? false;

            return GestureDetector(
              onLongPress: () => _showBottomSheet(index), // 支持长按操作
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  children: [
                    Card(
                      elevation: 4.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (game['imagePath'] != null &&
                              game['imagePath'].isNotEmpty)
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: kIsWeb
                                  ? Image.network(
                                      game['imagePath'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
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
                          ListTile(
                            title: Text(
                              game['title'],
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              game['description'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isGenerating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (isFailed)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
