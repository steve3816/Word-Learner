import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/word_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '單字本',
      theme: buildAppTheme(),
      home: const WordListScreen(),
    );
  }
}
