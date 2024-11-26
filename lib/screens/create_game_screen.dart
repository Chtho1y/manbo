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
  final int? initialIndex; // 初始索引参数

  const CreateGameScreen({
    super.key,
    required this.onGameCreated,
    this.initialData,
    this.initialIndex, // 初始化索引
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
      _optimizationController.text = ''; // 可以提供优化建议模板（你对游戏的优化建议...）
      _imagePath = initialData['imagePath'];
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
        return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>错误提示</title>
    <style>
        body {
            margin: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            font-family: Arial, sans-serif;
            background-color: #f9f9f9;
            color: #333;
        }
        .message-container {
            text-align: center;
            padding: 20px;
            border: 1px solid #ccc;
            background-color: #fff;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            border-radius: 8px;
        }
        .message-container h1 {
            font-size: 20px;
            margin-bottom: 10px;
        }
        .message-container p {
            font-size: 16px;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="message-container">
        <h1>游戏生成失败</h1>
        <p>API 调用地址、密钥或模型名称未设置，请在设置页面填写。</p>
    </div>
</body>
</html>
''';
      }

      final content = originalHtml == null
          ? '[游戏名称：$title\n游戏需求描述为：$description]现在制作该游戏的单文件HTML网页代码，以"<!DOCTYPE html>"开头'
          : '[游戏的HTML代码为：$originalHtml\n给出的优化建议：$optimizationSuggestion]现在参考优化建议继续迭代游戏的HTML代码，输出修改后的完整单文件HTML代码，以"<!DOCTYPE html>"开头';

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
**Task**：
根据用户的游戏开发需求，生成一个完整的、非常适合运行在移动设备的单文件HTML代码。输出应包括完整的HTML标记、相关标签、必要的CSS和完整的JavaScript代码。

**指导原则**：
1. **理解用户需求**：
   - 仔细阅读用户的游戏开发要求。
   - 确定核心游戏机制、目标和任何特定功能。

2. **分步骤思考和规划**：
   - **结构规划**：确定需要的HTML结构，包括`<head>`、`<body>`、`<script>`和`<style>`标签。
   - **功能规划**：列出需要实现的功能，如事件监听、游戏循环等。

3. **代码实现**：
   - **HTML**：
     - 使用语义化的HTML标签，确保结构清晰。
     - 所有的图片标签`<img>`都应包含`alt`文本，描述图片的风格和主题，并包含`width`和`height`属性。
     - 例子：
       ```html
       <img alt="sunset over a pond, film photograph, 1970" src="sunset.jpg" width="600" height="400">
       ```
   - **CSS**：
     - 使用精简且有效的CSS来绘制和动画视觉元素。
     - 确保样式与游戏主题一致。
   - **JavaScript**：
     - 只在需要时使用`<script>`标签，不要留下占位符注释。
     - 编写可运行的代码，保持代码高效有意义。
     - 使用ES6+特性，提升代码质量和可读性。

4. **交互性**：
   - 如果输出包含输入字段，确保它们位于`<form>`元素内，且表单具有`method="GET"`和适当的`action`属性。
   - 确保用户可以输入数据，并在下一次请求中接收到他们的自由输入。

5. **链接和导航**：
   - 为页面添加与内容相关的内部链接，使用完整的`href="https://example.com/"`格式。
   - 避免使用`href="#"`的链接。
   - 创造性地使用域名层次结构或URL参数，使网站内容与用户的上下文和意图相关。

6. **自我检查和纠错**：
   - 在完成代码后，仔细审查，确保没有语法错误或逻辑漏洞。
   - 测试主要功能，确保游戏可以正常运行。
   - 如果发现问题，及时修正，确保用户得到的是高质量的、可完美运行的代码。
   - 绝对不可以用任何方式省略任何代码！即使是复用的内容也不可以省略，确保输出完整的逻辑！

**示例结构**：
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>游戏标题</title>
    <style>
        /* 在这里添加CSS样式 */
    </style>
</head>
<body>
    <!-- 在这里添加HTML元素 -->
    <script>
        // 在这里添加JavaScript代码
    </script>
</body>
</html>
```
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

    // 提前保存到任务队列，并设置 `isGenerating` 为 true
    widget.onGameCreated(
      _gameTitleController.text,
      _gameDescriptionController.text,
      '', // 初始HTML为空
      _imagePath ?? '', // 提交图片路径
    );

    // 直接返回上一个页面
    Navigator.pop(context);

    try {
      // 异步生成任务
      final generatedHtml = await _generateGameHtml(
        _gameTitleController.text,
        _gameDescriptionController.text,
        originalHtml,
        optimizationSuggestion,
      );

      if (generatedHtml.isNotEmpty) {
        // 在生成任务完成时更新数据
        widget.onGameCreated(
          _gameTitleController.text,
          _gameDescriptionController.text,
          generatedHtml, // 提交生成的 HTML 内容
          _imagePath ?? '', // 提交图片路径
        );
      } else {
        // 如果生成的HTML为空，则视为失败
        throw Exception('生成的HTML内容为空');
      }
    } catch (e) {
      // 捕获生成失败的异常，并更新状态为失败
      widget.onGameCreated(
        _gameTitleController.text,
        _gameDescriptionController.text,
        '', // HTML内容为空
        _imagePath ?? '', // 提交图片路径
      );

      // 显示失败提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成失败'),
          content: Text('生成游戏失败：$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
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
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: CircularProgressIndicator(),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _onGenerateGame,
                  child: const Text('生成'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
