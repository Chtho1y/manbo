import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateGameScreen extends StatefulWidget {
  final Function(String title, String description, String htmlContent,
      String imagePath) onGameCreated;

  final Map<String, dynamic>? initialData;

  const CreateGameScreen({
    super.key,
    required this.onGameCreated,
    this.initialData,
  });

  @override
  _CreateGameScreenState createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final TextEditingController _gameTitleController = TextEditingController();
  final TextEditingController _gameDescriptionController =
      TextEditingController();
  final TextEditingController _optimizationController =
      TextEditingController(); // 优化输入框
  String? _imagePath;
  bool _isLoading = false;

  late final bool isEditMode;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.initialData != null; // 在 initState 初始化 isEditMode

    if (isEditMode) {
      final initialData = widget.initialData!;
      _gameTitleController.text = initialData['title'] ?? '';
      _gameDescriptionController.text = initialData['description'] ?? '';
      _optimizationController.text = '';
      _imagePath = initialData['imagePath'];

      // 预填充优化建议
      if (initialData.containsKey('htmlContent')) {
        _optimizationController.text = '你对游戏的优化建议...'; // 可以提供优化建议模板（可选）
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  Future<String> _generateGameHtml(
    String title,
    String description,
    String? originalHtml,
    String optimizationSuggestion,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final apiEndpoint = prefs.getString('apiEndpoint') ?? '';
      final apiKey = prefs.getString('apiKey') ?? '';
      final modelName = prefs.getString('modelName') ?? '';

      if (apiEndpoint.isEmpty || apiKey.isEmpty || modelName.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: const Text('API 调用地址、密钥或模型名称未设置，请在设置页面填写。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return '';
      }

      final content = originalHtml == null
          ? '[游戏名称：$title\n游戏需求描述为：$description]现在制作该游戏的单文件HTML网页代码，以"<!DOCTYPE html>"开头'
          : '[游戏的HTML代码为：$originalHtml\n给出的优化建议：$optimizationSuggestion]现在根据优化建议继续迭代该游戏的单文件HTML网页代码，以"<!DOCTYPE html>"开头';

      final response = await Dio().post(
        apiEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': '''

'''
            },
            {'role': 'user', 'content': content},
          ],
        },
      );

      final rawOutput = response.data['choices'][0]['message']['content'];
      final htmlMatch =
          RegExp(r'<html.*?>[\s\S]*?</html>', caseSensitive: false)
              .firstMatch(rawOutput);

      if (htmlMatch != null) {
        return htmlMatch.group(0) ?? '';
      } else {
        throw Exception('未检测到有效的代码内容，请重试。');
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: Text('生成游戏失败：$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return '';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onGenerateGame() async {
    if (_gameTitleController.text.isEmpty ||
        _gameDescriptionController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('提示'),
          content: Text('请填写完整的游戏名称和需求描述！'),
        ),
      );
      return;
    }

    // 根据 isEditMode 决定是否使用原始 HTML
    final originalHtml =
        widget.initialData != null ? widget.initialData!['htmlContent'] : null;
    final optimizationSuggestion =
        isEditMode ? _optimizationController.text : ''; // 非编辑模式下优化建议为空

    final generatedHtml = await _generateGameHtml(
      _gameTitleController.text,
      _gameDescriptionController.text,
      originalHtml,
      optimizationSuggestion,
    );

    if (generatedHtml.isNotEmpty) {
      widget.onGameCreated(
        _gameTitleController.text,
        _gameDescriptionController.text, // 提交需求描述
        generatedHtml, // 提交生成的 HTML 内容
        _imagePath ?? '', // 提交图片路径
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '修改游戏' : '创建新游戏'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _gameTitleController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '游戏名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _gameDescriptionController,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: '游戏需求描述',
                    ),
                  ),
                  if (isEditMode) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _optimizationController,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: '优化建议',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('上传图片'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _imagePath != null && _imagePath!.isNotEmpty
                        ? Container(
                            width: 300.0,
                            height: 300.0,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: kIsWeb
                                  ? Image.network(
                                      _imagePath!,
                                      fit: BoxFit.contain,
                                    )
                                  : Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          )
                        : Container(
                            width: 300.0,
                            height: 300.0,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.image,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8.0),
                                Text(
                                  '未选择图片',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _onGenerateGame,
                  child: const Text('生成游戏'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
