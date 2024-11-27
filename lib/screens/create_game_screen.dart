import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:manbo/models/llm_task.dart';
import 'package:uuid/uuid.dart';
import '../models/call_llm_task_manager.dart';

class CreateGameScreen extends StatefulWidget {
  final Function(
    String? gameId,
    String title,
    String description,
    String htmlContent,
    String imagePath,
    bool isGenerating,
    bool isFailed,
    String? taskId,
  ) onGameCreated;

  /// 初始数据（用于编辑模式）
  final Map<String, dynamic>? initialData;

  /// 游戏ID（用于编辑模式）
  final String? gameId;

  const CreateGameScreen({
    Key? key,
    required this.onGameCreated,
    this.initialData,
    this.gameId,
  }) : super(key: key);

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
  final Uuid uuid = Uuid(); // UUID生成器
  late final bool isEditMode; // 是否为编辑模式
  late final String? gameId; // 当前游戏ID
  Stream<LLMTask>? _taskStream; // 任务状态流

  @override
  void initState() {
    super.initState();
    isEditMode = widget.initialData != null; // 在 initState 初始化 isEditMode
    gameId = widget.gameId;

    if (isEditMode && widget.initialData != null) {
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

  /// 生成游戏HTML内容
  void _onGenerateGame() async {
    if (_gameTitleController.text.isEmpty ||
        _gameDescriptionController.text.isEmpty) {
      // 提示用户填写完整信息
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('提示'),
          content: Text('请填写完整的游戏名称和需求描述！'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true; // 显示加载状态
    });

    // 根据 isEditMode 决定是否使用原始 HTML
    final originalHtml =
        widget.initialData != null ? widget.initialData!['htmlContent'] : null;
    final optimizationSuggestion =
        isEditMode ? _optimizationController.text : ''; // 非编辑模式下优化建议为空

    String? currentGameId = gameId;

    if (!isEditMode) {
      // 生成新的游戏ID
      currentGameId = uuid.v4();
    }

    // 先保存游戏状态，标记为生成中
    widget.onGameCreated(
      currentGameId, // 传递游戏ID
      _gameTitleController.text,
      _gameDescriptionController.text,
      '', // 初始HTML为空
      _imagePath ?? '', // 图片路径
      true, // isGenerating
      false, // isFailed
      null, // taskId暂时为空
    );

    // 准备与模型交互的消息
    final messages = [
      {
        'role': 'system',
        'content': '''
**Task**：
根据用户的游戏开发需求，生成一个完整的、可运行在移动端的单文件HTML网页代码。输出应包括完整的HTML标记、相关标签、必要的CSS和完整的JavaScript代码。

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
      {
        'role': 'user',
        'content': originalHtml == null
            ? '[游戏名称：${_gameTitleController.text}\n游戏需求描述为：${_gameDescriptionController.text}]现在制作该游戏的单文件HTML网页代码，以"<!DOCTYPE html>"开头'
            : '[游戏的HTML代码为：$originalHtml\n给出的优化建议：$optimizationSuggestion]现在参考优化建议继续迭代游戏的HTML代码，输出修改后的完整单文件HTML代码，以"<!DOCTYPE html>"开头',
      },
    ];

    try {
      // 启动一个新的任务
      final taskId = await CallLLMTaskManager.instance.startTask(messages);

      // 将任务ID与游戏关联，更新游戏状态并传回taskId
      widget.onGameCreated(
        currentGameId,
        _gameTitleController.text,
        _gameDescriptionController.text,
        '',
        _imagePath ?? '',
        true,
        false,
        taskId, // 传递taskId
      );

      // 关闭当前页面，返回上一页
      Navigator.pop(context);
    } catch (e) {
      // 处理启动任务时的异常
      widget.onGameCreated(
        currentGameId, // 游戏ID
        _gameTitleController.text,
        _gameDescriptionController.text,
        '', // HTML内容为空
        _imagePath ?? '', // 图片路径
        false, // isGenerating
        true, // isFailed
        null, // taskId为空
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
    } finally {
      setState(() {
        _isLoading = false; // 结束加载状态
      });
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
