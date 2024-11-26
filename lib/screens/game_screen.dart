import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:manbo/screens/create_game_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/webview_page.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏制作'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // 调用HomeScreen的左侧菜单
            },
          ),
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
                      final existingIndex = games.indexWhere(
                        (game) => game['title'] == title,
                      );

                      if (existingIndex == -1) {
                        _upsertGame(
                          title: title,
                          description: description,
                          htmlContent: htmlContent,
                          imagePath: imagePath,
                          isGenerating: htmlContent.isEmpty,
                          isFailed: false,
                        );
                      } else {
                        _upsertGame(
                          index: existingIndex,
                          title: title,
                          description: description,
                          htmlContent: htmlContent,
                          imagePath: imagePath,
                          isGenerating: htmlContent.isEmpty,
                          isFailed: htmlContent.isEmpty,
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
      drawer: Drawer(
        // 您的侧边栏内容
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                '菜单',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            // 添加其他菜单项
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: games.isEmpty
            ? const Center(
                child: Text('暂无游戏内容，点击右上角添加游戏'),
              )
            : MasonryGridView.builder(
                gridDelegate:
                    const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 设置为两列
                ),
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  final aspectRatio = game['aspectRatio'] ?? (16 / 9); // 默认宽高比
                  final isGenerating = game['isGenerating'] ?? false;
                  final isFailed = game['isFailed'] ?? false;

                  return GestureDetector(
                    onTap: () {
                      if (!isGenerating &&
                          !isFailed &&
                          (game['htmlContent'] as String).isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebViewPage.fromHtml(
                              htmlContent: game['htmlContent'],
                              title: game['title'],
                            ),
                          ),
                        );
                      }
                    },
                    onLongPress: () => _showBottomSheet(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6.0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 使用 AspectRatio 计算图片高度
                                AspectRatio(
                                  aspectRatio: aspectRatio,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12.0),
                                      topRight: Radius.circular(12.0),
                                    ),
                                    child: game['imagePath'] != null &&
                                            (game['imagePath'] as String)
                                                .isNotEmpty
                                        ? kIsWeb
                                            ? Image.network(
                                                game['imagePath'],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              )
                                            : (File(game['imagePath'])
                                                    .existsSync()
                                                ? Image.file(
                                                    File(game['imagePath']),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Icon(
                                                      Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.grey,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ))
                                        : const Icon(
                                            Icons.image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        game['title'],
                                        style: const TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      Text(
                                        game['description'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Overlay for loading or error
                            if (isGenerating && !isFailed)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
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
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
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
                    ),
                  );
                },
              ),
      ),
    );
  }
}
