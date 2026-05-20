enum AiProvider { deepseek, openai, claude, gemini }

extension AiProviderLabel on AiProvider {
  String get displayName {
    switch (this) {
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

  String get modelName {
    switch (this) {
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
