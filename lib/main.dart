import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

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
      ),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}
