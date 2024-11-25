import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manbo/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  await copyDefaultImageToFileSystem();

  runApp(
      MyApp(initialThemeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light));
}

Future<void> copyDefaultImageToFileSystem() async {
  final directory = await getApplicationDocumentsDirectory();
  final defaultImagePath = '${directory.path}/default_image.png';

  // 检查是否已经存在，避免重复复制
  final file = File(defaultImagePath);
  if (await file.exists()) {
    return;
  }

  // 从 assets 中复制图片到文件系统
  final byteData = await rootBundle.load('assets/images/default_image.png');
  await file.writeAsBytes(byteData.buffer.asUint8List());
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

  void setTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'manbo',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}
