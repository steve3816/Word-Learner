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
}

abstract class AiService {
  Future<String> generateChinese(String englishWord);
  Future<String> generateExample(String englishWord);
}
