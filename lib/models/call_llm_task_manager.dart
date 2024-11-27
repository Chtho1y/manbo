import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_task.dart';
import 'task_status.dart';
import 'package:uuid/uuid.dart';

/// 管理LLM调用任务的管理器，采用单例模式
class CallLLMTaskManager {
  // 私有构造函数
  CallLLMTaskManager._privateConstructor();

  // 单例实例
  static final CallLLMTaskManager instance =
      CallLLMTaskManager._privateConstructor();

  final Dio _dio = Dio(); // Dio实例用于HTTP请求
  final Uuid _uuid = Uuid(); // UUID生成器

  late String _apiEndpoint; // API调用地址
  late String _apiKey; // API密钥
  late String _modelName; // 使用的模型名称

  bool _isInitialized = false; // 是否已初始化

  // 用于跟踪所有任务的映射，任务ID对应LLMTask
  final Map<String, LLMTask> _tasks = {};

  /// 初始化管理器，通过加载API配置
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _apiEndpoint = prefs.getString('apiEndpoint') ?? '';
    _apiKey = prefs.getString('apiKey') ?? '';
    _modelName = prefs.getString('modelName') ?? '';

    if (_apiEndpoint.isEmpty || _apiKey.isEmpty || _modelName.isEmpty) {
      throw Exception('API配置缺失。请在设置页面填写API调用地址、密钥和模型名称。');
    }

    _isInitialized = true;
  }

  /// 启动一个新的LLM任务，返回任务ID
  Future<String> startTask(List<Map<String, dynamic>> messages) async {
    await initialize();

    final String taskId = _uuid.v4(); // 生成唯一任务ID
    final LLMTask task =
        LLMTask(id: taskId, status: TaskStatus.generating); // 创建新的任务
    _tasks[taskId] = task; // 添加到任务映射中

    // 异步调用模型API
    _callModelAPI(task, messages);

    return taskId;
  }

  /// 获取指定任务ID的任务状态流
  Stream<LLMTask>? getTaskStream(String taskId) {
    return _tasks[taskId]?.stream;
  }

  /// 内部方法，调用模型API并更新任务状态
  Future<void> _callModelAPI(
      LLMTask task, List<Map<String, dynamic>> messages) async {
    try {
      final response = await _dio.post(
        _apiEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _modelName,
          'messages': messages,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices']?[0]?['message']?['content'];
        if (content != null && content is String && content.isNotEmpty) {
          task.update(status: TaskStatus.completed, result: content);
        } else {
          task.update(status: TaskStatus.failed, error: '响应中未包含有效内容。');
        }
      } else {
        task.update(
            status: TaskStatus.failed,
            error: 'API错误：${response.statusCode} ${response.statusMessage}');
      }
    } catch (e) {
      task.update(status: TaskStatus.failed, error: '调用模型API失败：$e');
    }
  }

  /// 释放指定任务的资源
  void disposeTask(String taskId) {
    _tasks[taskId]?.dispose();
    _tasks.remove(taskId);
  }

  /// 重新加载API配置
  Future<void> reloadConfig() async {
    _isInitialized = false;
    await initialize();
  }
}
