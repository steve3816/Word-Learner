import 'dart:convert';

class ExampleSentence {
  final String sentence;
  final String? chineseTranslation;

  const ExampleSentence({required this.sentence, this.chineseTranslation});

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
