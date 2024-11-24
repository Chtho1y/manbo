import 'package:flutter/material.dart';
import 'package:manbo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 模型选择的映射
  static const Map<String, Map<String, String>> models = {
    'OpenAI': {
      'ChatGPT-4o-mini': 'gpt-4-mini',
      'ChatGPT-4': 'gpt-4',
      'ChatGPT-4o': 'gpt-4o'
    },
    'Anthropic': {
      'Claude-3.5-sonnet': 'claude-3-5-sonnet',
      'Claude-3-opus': 'claude-3-opus',
    },
    '科大讯飞': {
      '讯飞-Spark-Lite': 'lite',
      '讯飞-Spark-Pro': 'generalv3',
      '讯飞-Spark-Pro-128K': 'pro-128k',
      '讯飞-Spark-Max': 'generalv3.5',
      '讯飞-Spark-Max-32K': 'max-32k',
      '讯飞-Spark-4.0-Ultra': '4.0Ultra',
    },
    '智谱清言': {
      '智谱-GLM-4-flash': 'glm-4-flash',
      '智谱-GLM-4-flashx': 'glm-4-flashx',
      '智谱-GLM-4-long': 'glm-4-long',
      '智谱-GLM-4-airx': 'glm-4-airx',
      '智谱-GLM-4-air': 'glm-4-air',
      '智谱-GLM-4': 'glm-4',
      '智谱-GLM-4-plus': 'glm-4-plus',
    },
  };

  Future<void> _setValue(
      BuildContext context, String key, String title, String hint,
      {bool obscureText = false}) async {
    final controller = TextEditingController();

    // 获取当前保存的值
    final prefs = await SharedPreferences.getInstance();
    controller.text = prefs.getString(key) ?? "";

    // 弹出输入框来修改值
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: obscureText, // 是否脱敏显示
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear(); // 清除内容
                },
              ),
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

    // 如果用户输入了新值，保存到 SharedPreferences 中
    if (result != null && result.isNotEmpty) {
      await prefs.setString(key, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title 已更新')),
      );
    }
  }

  Future<void> _setModel(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // 当前选择的厂商和模型
    String? selectedVendor = prefs.getString('modelVendor') ?? 'OpenAI';
    String? selectedModel = prefs.getString('modelName') ?? 'gpt-4o-mini';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择模型'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 厂商选择下拉框
                  DropdownButton<String>(
                    value: selectedVendor,
                    items: models.keys.map((vendor) {
                      return DropdownMenuItem(
                        value: vendor,
                        child: Text(vendor),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVendor = value;
                        selectedModel = models[selectedVendor!]!
                            .entries
                            .first
                            .value; // 切换厂商时重置模型为第一个
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedVendor != null)
                    DropdownButton<String>(
                      value: selectedModel,
                      items: models[selectedVendor!]!.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.value,
                          child: Text(entry.key),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedModel = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // 取消操作
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedVendor != null && selectedModel != null) {
                      await prefs.setString('modelVendor', selectedVendor!);
                      await prefs.setString('modelName', selectedModel!);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('模型设置已更新')),
                      );
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
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
            onTap: () =>
                _setValue(context, 'systemPrompt', '设置系统提示词', '请输入新的系统提示词'),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('设置 API 调用地址'),
            onTap: () => _setValue(
                context, 'apiEndpoint', '设置 API 调用地址', '请输入新的 API 调用地址'),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('设置 API 密钥'),
            onTap: () => _setValue(
              context,
              'apiKey',
              '设置 API 密钥',
              '请输入新的 API 密钥',
              obscureText: true, // 设置脱敏显示
            ),
          ),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text('选择模型'),
            onTap: () => _setModel(context), // 模型选择
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
