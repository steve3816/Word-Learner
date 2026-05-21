import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  Future<String> complete(String prompt) async {
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
      }),
    );
    debugPrint('[AI] $model ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return (data['choices'][0]['message']['content'] as String).trim();
  }
}
