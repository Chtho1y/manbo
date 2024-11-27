import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:manbo/models/call_llm_task_manager.dart';
import 'package:manbo/models/llm_task.dart';
import 'package:manbo/models/task_status.dart';
import 'package:manbo/screens/create_game_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/webview_page.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:uuid/uuid.dart'; // 导入 uuid 库

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Map<String, dynamic>> games = [];

  final Uuid uuid = Uuid(); // 初始化 uuid
  // 用于跟踪任务监听器
  final Map<String, StreamSubscription<LLMTask>> _taskSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    // 取消所有任务监听器
    for (var subscription in _taskSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
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

  /// 插入或更新游戏
  Future<void> _upsertGame({
    required String? id, // 使用 id 代替 index
    required String title,
    required String description,
    required String htmlContent,
    required String imagePath,
    bool isGenerating = false,
    bool isFailed = false,
    String? taskId, // 新增 taskId
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

    final existingGameIndex = games.indexWhere((game) => game['id'] == id);
    if (existingGameIndex != -1) {
      final oldImagePath = games[existingGameIndex]['imagePath'];
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

      setState(() {
        games[existingGameIndex] = {
          'id': id,
          'title': title,
          'description': description,
          'htmlContent': htmlContent,
          'imagePath': newPath,
          'isGenerating': isGenerating,
          'isFailed': isFailed,
          'aspectRatio': aspectRatio,
          'taskId': taskId, // 更新 taskId
        };
      });

      // 如果游戏开始生成并且有 taskId，设置任务监听器
      if (isGenerating && taskId != null) {
        _listenToTask(id!, taskId);
      }
    } else {
      // 创建新游戏
      setState(() {
        games.add({
          'id': id,
          'title': title,
          'description': description,
          'htmlContent': htmlContent,
          'imagePath': imagePath,
          'isGenerating': isGenerating,
          'isFailed': isFailed,
          'aspectRatio': aspectRatio,
          'taskId': taskId, // 新增 taskId
        });
      });

      // 如果游戏开始生成并且有 taskId，设置任务监听器
      if (isGenerating && taskId != null) {
        _listenToTask(id!, taskId);
      }
    }

    _saveGames();
  }

  /// 监听指定任务的状态
  void _listenToTask(String gameId, String taskId) {
    // 检查是否已存在监听器
    if (_taskSubscriptions.containsKey(taskId)) {
      return;
    }

    final taskStream = CallLLMTaskManager.instance.getTaskStream(taskId);
    if (taskStream == null) return;

    final subscription = taskStream.listen((task) {
      if (task.status == TaskStatus.completed) {
        // 尝试从task.result中提取HTML
        final extractedHtml = _extractHtml(task.result ?? '');

        if (extractedHtml != null && extractedHtml.isNotEmpty) {
          // 更新游戏状态为完成，并设置提取后的htmlContent
          _upsertGame(
            id: gameId,
            title: games.firstWhere((game) => game['id'] == gameId)['title'],
            description:
                games.firstWhere((game) => game['id'] == gameId)['description'],
            htmlContent: extractedHtml,
            imagePath:
                games.firstWhere((game) => game['id'] == gameId)['imagePath'],
            isGenerating: false,
            isFailed: false,
            taskId: null, // 任务已完成，移除 taskId
          );
        } else {
          // 提取失败，更新游戏状态为失败
          _upsertGame(
            id: gameId,
            title: games.firstWhere((game) => game['id'] == gameId)['title'],
            description:
                games.firstWhere((game) => game['id'] == gameId)['description'],
            htmlContent: '',
            imagePath:
                games.firstWhere((game) => game['id'] == gameId)['imagePath'],
            isGenerating: false,
            isFailed: true,
            taskId: null, // 任务已完成，移除 taskId
          );

          // 显示失败提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成游戏失败：无法提取有效的HTML内容。')),
          );
        }
      } else if (task.status == TaskStatus.failed) {
        // 更新游戏状态为失败
        _upsertGame(
          id: gameId,
          title: games.firstWhere((game) => game['id'] == gameId)['title'],
          description:
              games.firstWhere((game) => game['id'] == gameId)['description'],
          htmlContent: '',
          imagePath:
              games.firstWhere((game) => game['id'] == gameId)['imagePath'],
          isGenerating: false,
          isFailed: true,
          taskId: null, // 任务已完成，移除 taskId
        );

        // 显示失败提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成游戏失败：${task.error}')),
        );
      }
    });

    // 将监听器添加到映射中
    _taskSubscriptions[taskId] = subscription;
  }

  /// 从原始输出中提取HTML内容
  String? _extractHtml(String rawOutput) {
    final htmlMatch = RegExp(r'<html.*?>[\s\S]*?</html>', caseSensitive: false)
        .firstMatch(rawOutput);
    return htmlMatch?.group(0);
  }

  /// 删除游戏
  void _deleteGame(String id) {
    final existingGameIndex = games.indexWhere((game) => game['id'] == id);
    if (existingGameIndex != -1) {
      final imagePath = games[existingGameIndex]['imagePath'];
      if (imagePath != null && File(imagePath).existsSync()) {
        File(imagePath).deleteSync();
      }

      // 如果有任务正在进行，取消监听器
      final taskId = games[existingGameIndex]['taskId'];
      if (taskId != null && _taskSubscriptions.containsKey(taskId)) {
        _taskSubscriptions[taskId]?.cancel();
        _taskSubscriptions.remove(taskId);
      }

      setState(() {
        games.removeAt(existingGameIndex);
      });
      _saveGames();
    }
  }

  /// 显示游戏操作底部菜单
  Future<void> _showBottomSheet(String id) async {
    final game = games.firstWhere((game) => game['id'] == id, orElse: () => {});
    if (game.isEmpty) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (game['isFailed'] == true)
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
      _regenerateGame(id);
    } else if (action == 'edit') {
      final game =
          games.firstWhere((game) => game['id'] == id, orElse: () => {});
      if (game.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateGameScreen(
            gameId: id, // 传递 id
            onGameCreated: (
              String? gameId,
              String title,
              String description,
              String htmlContent,
              String imagePath,
              bool isGenerating,
              bool isFailed,
              String? taskId,
            ) {
              _upsertGame(
                id: gameId,
                title: title,
                description: description,
                htmlContent: htmlContent,
                imagePath: imagePath,
                isGenerating: isGenerating,
                isFailed: isFailed,
                taskId: taskId,
              );
            },
            initialData: game,
          ),
        ),
      );
    } else if (action == 'delete') {
      _deleteGame(id);
    }
  }

  /// 重新生成游戏HTML内容
  Future<void> _regenerateGame(String id) async {
    final game = games.firstWhere((game) => game['id'] == id, orElse: () => {});
    if (game.isEmpty) return;

    final String title = game['title'] ?? '';
    final String description = game['description'] ?? '';
    final String? originalHtml = game['htmlContent'];
    final String imagePath = game['imagePath'] ?? '';

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('游戏名称或描述为空，无法重新生成。')),
      );
      return;
    }

    // 更新游戏状态为生成中
    _upsertGame(
      id: id,
      title: title,
      description: description,
      htmlContent: '',
      imagePath: imagePath,
      isGenerating: true,
      isFailed: false,
      taskId: null, // 重新生成前无任务ID
    );

    // 准备与模型交互的消息
    final messages = [
      {
        'role': 'system',
        'content': '''
        你是一个帮助用户生成游戏HTML代码的助手。
        '''
      },
      {
        'role': 'user',
        'content': originalHtml == null
            ? '[游戏名称：$title\n游戏需求描述为：$description]现在制作该游戏的单文件HTML网页代码，以"<!DOCTYPE html>"开头'
            : '[游戏的HTML代码为：$originalHtml]现在继续迭代游戏的HTML代码，输出修改后的完整单文件HTML代码，以"<!DOCTYPE html>"开头',
      },
    ];

    try {
      // 启动一个新的任务
      final taskId = await CallLLMTaskManager.instance.startTask(messages);

      // 更新游戏状态为生成中，并关联 taskId
      _upsertGame(
        id: id,
        title: title,
        description: description,
        htmlContent: '',
        imagePath: imagePath,
        isGenerating: true,
        isFailed: false,
        taskId: taskId, // 关联任务ID
      );
    } catch (e) {
      // 处理启动任务时的异常
      _upsertGame(
        id: id,
        title: title,
        description: description,
        htmlContent: '',
        imagePath: imagePath,
        isGenerating: false,
        isFailed: true,
        taskId: null,
      );

      // 显示失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重新生成游戏失败：$e')),
      );
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
                    gameId: null, // 创建新游戏，无 id
                    onGameCreated: (
                      String? gameId,
                      String title,
                      String description,
                      String htmlContent,
                      String imagePath,
                      bool isGenerating,
                      bool isFailed,
                      String? taskId,
                    ) {
                      if (gameId == null) {
                        // 生成新的 id
                        String newId = uuid.v4();
                        _upsertGame(
                          id: newId,
                          title: title,
                          description: description,
                          htmlContent: htmlContent,
                          imagePath: imagePath,
                          isGenerating: isGenerating,
                          isFailed: isFailed,
                          taskId: taskId,
                        );
                      } else {
                        _upsertGame(
                          id: gameId,
                          title: title,
                          description: description,
                          htmlContent: htmlContent,
                          imagePath: imagePath,
                          isGenerating: isGenerating,
                          isFailed: isFailed,
                          taskId: taskId,
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
        child: games.isEmpty
            ? const Center(
                child: Text('点击右上角加号制作新游戏吧'),
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
                    onLongPress: () => _showBottomSheet(game['id']),
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
                                          color: Colors.black,
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
