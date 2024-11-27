import 'package:flutter/material.dart';
import 'package:manbo/models/call_llm_task_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  try {
    // Initialize the CallLLMTaskManager
    await CallLLMTaskManager.instance.initialize();
  } catch (e) {
    // Handle initialization errors, possibly by showing an alert or redirecting to a settings screen
    // For simplicity, we'll print the error here
    print('Error initializing CallLLMTaskManager: $e');
    // You might want to handle this more gracefully in a production app
  }

  runApp(
      MyApp(initialThemeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const MyApp({super.key, required this.initialThemeMode});

  @override
  MyAppState createState() => MyAppState();

  static MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>();
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode;

  MyAppState() : _themeMode = ThemeMode.light;

  void setTheme(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = themeMode;
    });
    await prefs.setBool('isDarkMode', themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'manbo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.black, // 主色为黑色，适配亮色模式
          onPrimary: const Color(0xFFF3F5F8), // 主色上的文字或图标
          surface: Colors.white, // 卡片等表面颜色
        ),
        scaffoldBackgroundColor: Colors.white, // 页面背景色
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20, // 设置全局 AppBar 标题字体大小
            // fontWeight: FontWeight.bold, // 设置字体粗细
            color: Colors.black, // 设置字体颜色
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            height: 1.2, // 调整行高
            textBaseline: TextBaseline.alphabetic, // 保证文字基线对齐
          ),
          bodyMedium: TextStyle(
            height: 1.2,
            textBaseline: TextBaseline.alphabetic,
          ),
          bodySmall: TextStyle(
            height: 1.2,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.white, // 主色为白色，适配暗黑模式
          onPrimary: Colors.black, // 主色上的文字或图标
          surface: const Color(0xFF121212), // 卡片等表面颜色
        ),
        scaffoldBackgroundColor: Colors.black, // 页面背景色
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFFFFF1C2), // 暗黑模式导航栏高亮颜色
          unselectedItemColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20, // 设置全局 AppBar 标题字体大小
            // fontWeight: FontWeight.bold, // 设置字体粗细
            color: Colors.white, // 设置字体颜色
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            height: 1.2, // 调整行高
            textBaseline: TextBaseline.alphabetic, // 保证文字基线对齐
          ),
          bodyMedium: TextStyle(
            height: 1.2,
            textBaseline: TextBaseline.alphabetic,
          ),
          bodySmall: TextStyle(
            height: 1.2,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
      ),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}
