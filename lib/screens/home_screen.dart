import 'package:flutter/material.dart';
import 'package:manbo/screens/game_screen.dart';
import 'chat_list_screen.dart';
import 'character_screen.dart';
import 'settings_screen.dart';
import 'webview_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // 初始化进入_tabs[_currentIndex]值对应的界面

  final List<Widget> _tabs = [
    const GameScreen(), // 游戏页面
    const CharacterScreen(), // 角色UGC页面
    const ChatListScreen(), // 对话页面
  ];

  void _openPrivacyPolicyPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: 'https://www.aiqwq.com/zh/privacypolicy',
          title: '隐私政策',
        ),
      ),
    );
  }

  void _openUserAgreementPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: 'https://www.aiqwq.com/zh/useragreement',
          title: '用户协议',
        ),
      ),
    );
  }

  void _openAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: 'https://www.aiqwq.com/',
          title: '关于我们',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('基础设置'),
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
              leading: const Icon(Icons.lock),
              title: const Text('隐私政策'),
              onTap: () => _openPrivacyPolicyPage(context),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('用户协议'),
              onTap: () => _openUserAgreementPage(context),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于我们'),
              onTap: () => _openAboutPage(context),
            ),
          ],
        ),
      ),
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
