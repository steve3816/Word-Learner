import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';
import 'openai_compatible_service.dart';
import 'claude_service.dart';

class SettingsService {
  static const _providerKey = 'selected_provider';
  static const _keyPrefix = 'api_key_';

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

  Future<void> setSelectedProvider(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
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
          model: 'deepseek-chat',
        );
      case AiProvider.openai:
        return OpenAiCompatibleService(
          apiKey: key,
          baseUrl: 'https://api.openai.com',
          model: 'gpt-4o-mini',
        );
      case AiProvider.claude:
        return ClaudeService(apiKey: key);
    }
  }

  Future<bool> hasAnyKey() async {
    for (final provider in AiProvider.values) {
      final key = await getApiKey(provider);
      if (key != null && key.isNotEmpty) return true;
    }
    return false;
  }
}
