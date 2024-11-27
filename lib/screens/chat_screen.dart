import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
import 'package:manbo/models/call_llm_task_manager.dart';
import 'package:manbo/models/llm_task.dart';
import 'package:manbo/models/task_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _systemPrompt = "";
  Stream<LLMTask>? _taskStream; // 任务状态流

  @override
  void initState() {
    super.initState();
    _loadSystemPrompt();
  }

  Future<void> _loadSystemPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _systemPrompt = prefs.getString('systemPrompt') ?? "";
    });

    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final dbMessages =
        await DatabaseHelper.instance.getMessages(widget.chat.id);
    setState(() {
      widget.chat.messages = dbMessages.map((msg) {
        return Message(
          id: msg['id'],
          role: msg['role'],
          content: msg['content'],
        );
      }).toList();
    });

    // 确保内容渲染完成后滚动到消息底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollToBottom();
      });
    });
  }

  /// 发送消息并处理回复
  void _sendMessage(String content) async {
    if (content.trim().isEmpty) return; // 如果内容为空，不发送

    // 创建用户消息
    final userMessage = Message(
      id: DateTime.now().toString(),
      role: 'user',
      content: content,
    );

    // 将用户消息插入数据库
    await DatabaseHelper.instance.insertMessage(
      userMessage.id,
      widget.chat.id,
      userMessage.role,
      userMessage.content,
    );

    setState(() {
      widget.chat.messages.add(userMessage);
    });

    _controller.clear(); // 清空输入框
    _scrollToBottom(); // 滚动到底部

    // 准备与模型交互的消息
    final messages = [
      if (_systemPrompt.isNotEmpty)
        {
          'role': 'system',
          'content': _systemPrompt,
        },
      ...widget.chat.messages.map((msg) => {
            'role': msg.role,
            'content': msg.content,
          }),
    ];

    try {
      // 启动一个新的任务
      final taskId = await CallLLMTaskManager.instance.startTask(messages);
      _taskStream = CallLLMTaskManager.instance.getTaskStream(taskId);

      // 监听任务状态更新
      _taskStream?.listen((task) async {
        if (task.status == TaskStatus.completed) {
          // 创建助手回复消息
          final assistantMessage = Message(
            id: DateTime.now().toString(),
            role: 'assistant',
            content: task.result ?? '',
          );

          // 将助手消息插入数据库
          await DatabaseHelper.instance.insertMessage(
            assistantMessage.id,
            widget.chat.id,
            assistantMessage.role,
            assistantMessage.content,
          );

          setState(() {
            widget.chat.messages.add(assistantMessage);
          });

          _scrollToBottom(); // 滚动到底部

          // 释放任务资源
          CallLLMTaskManager.instance.disposeTask(task.id);
        } else if (task.status == TaskStatus.failed) {
          // 显示错误提示
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('错误'),
              content: Text('无法获取回复：${task.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );

          // 释放任务资源
          CallLLMTaskManager.instance.disposeTask(task.id);
        }
      });
    } catch (e) {
      // 处理启动任务时的异常
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: Text('无法发送消息：$e'),
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

  Future<void> _deleteMessage(Message message) async {
    await DatabaseHelper.instance.deleteMessage(message.id);
    setState(() {
      widget.chat.messages.remove(message);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (_scrollController.position.pixels != maxScroll) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                  _showTopLog(context, '复制成功');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('删除'),
                onTap: () async {
                  await _deleteMessage(message);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTopLog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 自动延迟1秒关闭
        Future.delayed(const Duration(seconds: 1), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding:
                EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chat.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.chat.messages.length,
              itemBuilder: (context, index) {
                final message = widget.chat.messages[index];
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(message),
                  child: Align(
                    alignment: message.role == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      decoration: BoxDecoration(
                        color: message.role == 'user'
                            ? Colors.blue[100]
                            : const Color.fromARGB(255, 248, 240, 220),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.black, // 固定消息文字黑色不会跟随主题变化
                          fontSize: 16, // 字号
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    // cursorColor: Color(0xFFFFF1C2),
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      // focusedBorder: UnderlineInputBorder(
                      //   borderSide:
                      //       BorderSide(color: Color(0xFFFFF1C2), width: 2.0),
                      // ),
                    ),
                  ),
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/icon_send_white.svg' // 暗黑模式发送icon
                        : 'assets/images/icon_send.svg',
                    width: 32.0,
                    height: 32.0,
                  ),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
