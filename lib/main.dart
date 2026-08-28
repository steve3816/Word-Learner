import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/word_book_list_screen.dart';
import 'services/ad_service.dart';
import 'services/settings_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  WidgetService.syncWords();
  await SettingsService.loadShowProficiencyIcons();
  await SettingsService.loadShowCreatedAt();
  await SettingsService.loadHideChinese();
  runApp(const MyApp());
  // 延後到第一幀畫完才呼叫，避免廣告 SDK 的原生初始化卡住還沒開機完成的 App。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AdService.ensureInitialized();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haword',
      theme: buildAppTheme(),
      home: const WordBookListScreen(),
    );
  }
}
