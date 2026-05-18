import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class OpenAiCompatibleService implements AiService {
  final String apiKey;
  final String baseUrl;
  final String model;

  const OpenAiCompatibleService({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

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
      Uri.parse('$baseUrl/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 100,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return (data['choices'][0]['message']['content'] as String).trim();
  }
}
