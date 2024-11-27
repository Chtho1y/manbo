import 'dart:async';
import 'task_status.dart';

/// LLM任务类，表示一个独立的任务
class LLMTask {
  final String id; // 任务唯一标识
  TaskStatus status; // 当前任务状态
  String? result; // 任务结果
  String? error; // 错误信息（如果有）

  final StreamController<LLMTask> _controller =
      StreamController.broadcast(); // 任务状态流控制器

  LLMTask({
    required this.id,
    this.status = TaskStatus.pending,
    this.result,
    this.error,
  });

  /// 获取任务状态的流
  Stream<LLMTask> get stream => _controller.stream;

  /// 更新任务状态，并向监听者广播新的状态
  void update({TaskStatus? status, String? result, String? error}) {
    if (status != null) this.status = status;
    if (result != null) this.result = result;
    if (error != null) this.error = error;
    _controller.add(this);
  }

  /// 关闭流控制器，释放资源
  void dispose() {
    _controller.close();
  }
}
