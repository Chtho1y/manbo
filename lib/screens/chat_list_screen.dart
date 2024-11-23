import 'package:flutter/material.dart';
import 'package:manbo/screens/webview_page.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'settings_screen.dart'; // 引入新创建的设置页面

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Chat> chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final dbChats = await DatabaseHelper.instance.getChats();
    setState(() {
      chats = dbChats.map((chat) {
        return Chat(
          id: chat['id'],
          name: chat['name'],
          messages: [],
        );
      }).toList();
    });
  }

  Future<void> _deleteChat(String chatId) async {
    // 从数据库中删除
    await DatabaseHelper.instance.deleteChat(chatId);

    // 从 UI 中移除
    setState(() {
      chats.removeWhere((chat) => chat.id == chatId);
    });
  }

  Future<void> _renameChat(String chatId, String newName) async {
    // 更新数据库中的对话名称
    await DatabaseHelper.instance.updateChatName(chatId, newName);

    // 更新 UI
    setState(() {
      final chat = chats.firstWhere((chat) => chat.id == chatId);
      chat.name = newName;
    });
  }

  void _startNewChat() async {
    final newChat = Chat(
      id: const Uuid().v4(),
      name: '对话 ${chats.length + 1}',
      messages: [],
    );
    await DatabaseHelper.instance.insertChat(newChat.id, newChat.name);

    setState(() {
      chats.add(newChat);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chat: newChat),
      ),
    );
  }

  void _openAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: 'https://www.aiqwq.com/',
          title: '关于',
        ),
      ),
    );
  }

  void _onLongPress(Chat chat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context, 'rename');
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

    if (action == 'rename') {
      _showRenameDialog(chat);
    } else if (action == 'delete') {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除对话'),
          content: const Text('确定要删除这个对话及其所有记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        await _deleteChat(chat.id);
      }
    }
  }

  void _showRenameDialog(Chat chat) {
    final controller = TextEditingController(text: chat.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名对话'),
          content: TextField(
            controller: controller,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: '请输入新的对话名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 取消操作
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await _renameChat(chat.id, newName);
                }
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♥ 聊'),
        centerTitle: true,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer(); // 打开抽屉菜单
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startNewChat, // 新建对话
          ),
        ],
      ),
      drawer: Drawer(
        child: FractionallySizedBox(
          widthFactor: 1,
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                height: 40.0,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'manbo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('关于'),
                onTap: () => _openAboutPage(context),
              ),
            ],
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onLongPress: () => _onLongPress(chats[index]),
            child: ListTile(
              title: Text(chats[index].name),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chat: chats[index]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
