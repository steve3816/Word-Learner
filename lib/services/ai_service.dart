enum AiProvider { deepseek, openai, claude }

extension AiProviderLabel on AiProvider {
  String get displayName {
    switch (this) {
      case AiProvider.deepseek:
        return 'DeepSeek';
      case AiProvider.openai:
        return 'OpenAI';
      case AiProvider.claude:
        return 'Claude';
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
    }
  }
}

abstract class AiService {
  Future<String> complete(String prompt);
}
