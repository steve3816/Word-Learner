import 'dart:convert';

class ExampleSentence {
  final String sentence;
  final String? chineseTranslation;

  const ExampleSentence({required this.sentence, this.chineseTranslation});

  /// 請 AI 用 [parseJson] 看得懂的格式回應時，接在提示詞內容後面的固定格式指示。
  /// 這是程式解析回應用的機關，不是使用者可調整的內容。
  static const jsonFormatSuffix =
      ' Also provide its Traditional Chinese translation. '
      'Return a JSON object with exactly two fields: "sentence" (the English example) '
      'and "chineseTranslation" (the Traditional Chinese translation). '
      'Return only the JSON object, no markdown, no extra text.';

  Map<String, dynamic> toMap() => {
        'sentence': sentence,
        'chineseTranslation': chineseTranslation,
      };

  factory ExampleSentence.fromMap(Map<String, dynamic> map) => ExampleSentence(
        sentence: map['sentence'] as String,
        chineseTranslation: map['chineseTranslation'] as String?,
      );

  static ExampleSentence parseJson(String raw) {
    final cleaned =
        raw.replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll('```', '').trim();
    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    return ExampleSentence(
      sentence: map['sentence'] as String,
      chineseTranslation: map['chineseTranslation'] as String?,
    );
  }
}
