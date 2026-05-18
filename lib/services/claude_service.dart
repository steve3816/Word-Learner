import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class ClaudeService implements AiService {
  final String apiKey;

  const ClaudeService({required this.apiKey});

  @override
  Future<String> generateChinese(String englishWord) => _call(
        'The English word is "$englishWord". Provide a concise Chinese definition in 1-5 Chinese characters. Return only the Chinese definition, nothing else.',
      );

  @override
  Future<String> generateExample(String englishWord) => _call(
        'Write one simple, natural English example sentence using the word "$englishWord". Return only the sentence, nothing else.',
      );

  Future<String> _call(String prompt) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 100,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return (data['content'][0]['text'] as String).trim();
  }
}
