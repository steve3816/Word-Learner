import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'ai_service.dart';

/// 免費方案：打自家後端 `/api/chat`，由後端依序輪詢 Anthropic / OpenAI / Gemini，
/// 對使用者完全免費，不需要自己的 API Key。契約見 API.md。
///
/// 後端單次上游請求逾時 30 秒，失敗時最多換兩家再試，所以逾時設得比其他
/// provider 寬鬆一些。
class FreeAiService implements AiService {
  const FreeAiService();

  @override
  Future<String> complete(String prompt) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.freeAiBaseUrl}/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': prompt}),
        )
        .timeout(const Duration(seconds: 60));
    debugPrint('[AI] free ${response.statusCode}: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body, response.statusCode));
    }
    final data = jsonDecode(response.body);
    return (data['text'] as String).trim();
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final err = jsonDecode(body);
      final message = err['error'] as String?;
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {}
    return 'AI 服務回應異常（狀態碼 $statusCode）';
  }
}
