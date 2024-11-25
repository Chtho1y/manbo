import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
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

  Future<String> _callModelAPI(List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiEndpoint = prefs.getString('apiEndpoint') ?? '';
      final apiKey = prefs.getString('apiKey') ?? '';
      final modelName = prefs.getString('modelName') ?? '';

      if (apiEndpoint.isEmpty || apiKey.isEmpty || modelName.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: Text('API 调用地址、密钥或模型名称未设置，请在设置页面填写。'),
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

      final response = await Dio().post(
        apiEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': modelName, // 动态加载模型名称
          'messages': messages, // 消息上下文
        },
      );

      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: Text('无法获取回复，如果模型设置正常，请换句话或稍后重试。详细信息：($e)'),
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
  }

  void _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // 用户消息
    final userMessage = Message(
      id: DateTime.now().toString(),
      role: 'user',
      content: content,
    );

    await DatabaseHelper.instance.insertMessage(
      userMessage.id,
      widget.chat.id,
      userMessage.role,
      userMessage.content,
    );

    setState(() {
      widget.chat.messages.add(userMessage);
    });

    _controller.clear();
    _scrollToBottom();

    // 调用大模型 API
    final assistantReply = await _callModelAPI(
      [
        if (_systemPrompt.isNotEmpty)
          {'role': 'system', 'content': _systemPrompt},
        ...widget.chat.messages
            .map((msg) => {'role': msg.role, 'content': msg.content})
      ],
    );

    // 如果 API 返回空内容，不添加消息
    if (assistantReply.isEmpty) {
      // _showTopLog(context, '无法获取回复，请稍后重试。');
      return;
    }

    // 模型回复消息
    final assistantMessage = Message(
      id: DateTime.now().toString(),
      role: 'assistant',
      content: assistantReply,
    );

    await DatabaseHelper.instance.insertMessage(
      assistantMessage.id,
      widget.chat.id,
      assistantMessage.role,
      assistantMessage.content,
    );

    setState(() {
      widget.chat.messages.add(assistantMessage);
    });

    _scrollToBottom();
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
                    cursorColor: Colors.blue,
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
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
