import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

class WidgetService {
  static const _androidName = 'WordWidgetProvider';
  static final _db = DbHelper();

  static Future<void> syncWords() async {
    try {
      final words = await _db.getAllWords();
      final json = jsonEncode(words
          .map((w) => {
                'english': w.english,
                'chinese': w.chinese,
                'proficiency': w.proficiency,
              })
          .toList());
      debugPrint('[Widget] syncing ${words.length} words');
      // shared_preferences stores as flutter.<key> in FlutterSharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('words_json', json);
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (e) {
      debugPrint('[Widget] sync failed: $e');
    }
  }
}
