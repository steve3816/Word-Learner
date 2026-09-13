enum AiProvider { free, deepseek, openai, claude, gemini }

extension AiProviderLabel on AiProvider {
  String get displayName {
    switch (this) {
      case AiProvider.free:
        return '內建';
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.openai:
        return 'OpenAI';
      case AiProvider.claude:
        return 'Claude';
      case AiProvider.gemini:
        return 'Gemini';
    }
  }

  /// 顯示用的模型名稱。免費方案由後端輪詢多家服務，不對外表明實際模型。
  String get modelName {
    switch (this) {
      case AiProvider.free:
        return '';
      case AiProvider.deepseek:
        return 'deepseek-v4-flash';
      case AiProvider.openai:
        return 'gpt-4o-mini';
      case AiProvider.claude:
        return 'claude-haiku';
      case AiProvider.gemini:
        return 'gemini-3.5-flash';
    }
  }
}

abstract class AiService {
  Future<String> complete(String prompt);
}
