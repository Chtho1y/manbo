import 'package:flutter/material.dart';
import 'package:manbo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setSystemPrompt(BuildContext context) async {
    final controller = TextEditingController();

    // 获取当前保存的系统提示词
    final prefs = await SharedPreferences.getInstance();
    controller.text = prefs.getString('systemPrompt') ?? "";

    // 弹出输入框来修改系统提示词
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置系统提示词'),
          content: TextField(
            controller: controller,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: '请输入新的系统提示词',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 取消操作
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    // 如果用户输入了新的系统提示词，保存到 SharedPreferences 中
    if (result != null && result.isNotEmpty) {
      await prefs.setString('systemPrompt', result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统提示词已更新')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('系统提示'),
            onTap: () => _setSystemPrompt(context), // 修改系统提示词
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('暗黑模式'),
            trailing: Switch(
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (bool value) async {
                final prefs = await SharedPreferences.getInstance();
                if (value) {
                  prefs.setBool('isDarkMode', true);
                  MyApp.of(context)?.setTheme(ThemeMode.dark);
                } else {
                  prefs.setBool('isDarkMode', false);
                  MyApp.of(context)?.setTheme(ThemeMode.light);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
