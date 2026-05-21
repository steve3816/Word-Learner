import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class GeminiService implements AiService {
  final String apiKey;

  const GeminiService({required this.apiKey});

  static const _model = 'gemini-3.5-flash';

  @override
  Future<String> complete(String prompt) async {
    final response = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      }),
    );
    debugPrint('[AI] $_model ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200) {
      final message = _extractErrorMessage(response.body);
      throw Exception(message);
    }
    final data = jsonDecode(response.body);
    return (data['candidates'][0]['content']['parts'][0]['text'] as String)
        .trim();
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
