import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_svg/svg.dart';
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
    // 先加载系统提示词，再加载聊天信息
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _systemPrompt = prefs.getString('systemPrompt') ?? "";
    });

    _loadMessages(); // 加载聊天信息
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
  }

  Future<String> _callModelAPI(List<Map<String, dynamic>> messages) async {
    try {
      final response = await Dio().post(
        'https://spark-api-open.xf-yun.com/v1/chat/completions',
        data: {
          'model': 'lite', // 指定模型版本
          'messages': messages, // 消息上下文
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer LSYBgbFNPViuKrAdfTyT:LXWPTcxKpUGjKgVntotp',
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      return '无法获取回复，请稍后重试。 ($e)';
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                return Align(
                  alignment: message.role == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: message.role == 'user'
                          ? Colors.blue[100]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(message.content),
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
                    'assets/images/icon_send.svg',
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
