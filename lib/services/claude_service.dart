import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class ClaudeService implements AiService {
  final String apiKey;

  const ClaudeService({required this.apiKey});

  @override
  Future<String> complete(String prompt) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    ).timeout(const Duration(seconds: 10));
    debugPrint('[AI] claude ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }
    final data = jsonDecode(response.body);
    return (data['content'][0]['text'] as String).trim();
  }

  String _extractErrorMessage(String body) {
    try {
      final err = jsonDecode(body);
      final message = err['error']?['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return body;
  }
}
