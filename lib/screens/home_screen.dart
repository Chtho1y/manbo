import 'package:flutter/material.dart';
import 'package:manbo/screens/game_screen.dart';
import 'chat_list_screen.dart';
import 'character_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const GameScreen(), // 游戏页面
    const CharacterScreen(), // 角色UGC页面
    const ChatListScreen(), // 对话页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.gamepad),
            label: '游戏',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add),
            label: '广场',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '对话',
          ),
        ],
      ),
    );
  }
}
