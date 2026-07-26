import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';
import 'openai_compatible_service.dart';
import 'claude_service.dart';
import 'gemini_service.dart';
import '../utils/proficiency_util.dart';

class SettingsService {
  static const _providerKey = 'selected_provider';
  static const _keyPrefix = 'api_key_';
  static const _promptPrefix = 'prompt_';
  static const _quizMaxProficiencyKey = 'quiz_max_proficiency';
  static const _showProficiencyIconsKey = 'show_proficiency_icons';

  /// 列表類畫面是否顯示熟練度表情圖示。app 啟動時由 [loadShowProficiencyIcons] 從
  /// SharedPreferences 讀入初始值，之後透過 [setShowProficiencyIcons] 同步更新，
  /// 讓已經顯示中的畫面能立即反應，不用重新進入。
  static final ValueNotifier<bool> showProficiencyIcons = ValueNotifier(true);

  static Future<void> loadShowProficiencyIcons() async {
    final prefs = await SharedPreferences.getInstance();
    showProficiencyIcons.value =
        prefs.getBool(_showProficiencyIconsKey) ?? true;
  }

  Future<void> setShowProficiencyIcons(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showProficiencyIconsKey, value);
    showProficiencyIcons.value = value;
  }

  static const promptFields = ['english', 'chinese', 'explanation', 'example'];
  static const wordPlaceholder = '{word}';

  // Cached default prompts loaded from assets/config.json
  static Map<String, String>? _defaultPrompts;

  static Future<Map<String, String>> _loadDefaultPrompts() async {
    if (_defaultPrompts != null) return _defaultPrompts!;
    final raw = await rootBundle.loadString('assets/config.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _defaultPrompts = Map<String, String>.from(
      map['defaultPrompts'] as Map<String, dynamic>,
    );
    return _defaultPrompts!;
  }

  static Future<String> defaultPromptFor(String field) async {
    final prompts = await _loadDefaultPrompts();
    return prompts[field] ?? '';
  }

  static String promptLabel(String field) {
    switch (field) {
      case 'english':
        return '英文單字（由中文查詢）';
      case 'chinese':
        return '中文意思';
      case 'explanation':
        return '英文解釋';
      case 'example':
        return '例句＋中文翻譯';
      default:
        return field;
    }
  }

  Future<String> getPrompt(String field) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_promptPrefix$field') ??
        await defaultPromptFor(field);
  }

  Future<void> setPrompt(String field, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_promptPrefix$field', prompt);
  }

  Future<Map<String, String>> getAllPrompts() async {
    final result = <String, String>{};
    for (final field in promptFields) {
      result[field] = await getPrompt(field);
    }
    return result;
  }

  Future<void> setAllPrompts(Map<String, String> prompts) async {
    for (final entry in prompts.entries) {
      await setPrompt(entry.key, entry.value);
    }
  }

  Future<AiProvider?> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_providerKey);
    if (value == null) return null;
    try {
      return AiProvider.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSelectedProvider(AiProvider? provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == null) {
      await prefs.remove(_providerKey);
    } else {
      await prefs.setString(_providerKey, provider.name);
    }
  }

  Future<String?> getApiKey(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix${provider.name}');
  }

  Future<void> setApiKey(AiProvider provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${provider.name}', key);
  }

  Future<AiService?> getActiveService() async {
    final provider = await getSelectedProvider();
    if (provider == null) return null;
    final key = await getApiKey(provider);
    if (key == null || key.isEmpty) return null;
    switch (provider) {
      case AiProvider.deepseek:
        return OpenAiCompatibleService(
          apiKey: key,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-v4-flash',
        );
      case AiProvider.openai:
        return OpenAiCompatibleService(
          apiKey: key,
          baseUrl: 'https://api.openai.com',
          model: 'gpt-4o-mini',
        );
      case AiProvider.claude:
        return ClaudeService(apiKey: key);
      case AiProvider.gemini:
        return GeminiService(apiKey: key);
    }
  }

  Future<int> getQuizMaxProficiency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_quizMaxProficiencyKey) ?? ProficiencyLevel.proficient.score;
  }

  Future<void> setQuizMaxProficiency(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_quizMaxProficiencyKey, value);
  }

  Future<bool> hasAnyKey() async {
    for (final provider in AiProvider.values) {
      final key = await getApiKey(provider);
      if (key != null && key.isNotEmpty) return true;
    }
    return false;
  }
}
