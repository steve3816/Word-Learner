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

class Word {
  final int? id;
  final String english;
  final String chinese;
  final String? englishExplanation;
  final List<ExampleSentence> examples;
  final DateTime createdAt;

  const Word({
    this.id,
    required this.english,
    required this.chinese,
    this.englishExplanation,
    this.examples = const [],
    required this.createdAt,
  });

  // For quiz screen compatibility
  String? get exampleSentence => examples.isEmpty ? null : examples.first.sentence;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'english': english,
        'chinese': chinese,
        'english_explanation': englishExplanation,
        'examples_json': examples.isEmpty
            ? null
            : jsonEncode(examples.map((e) => e.toMap()).toList()),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Word.fromMap(Map<String, dynamic> map) {
    List<ExampleSentence> examples = [];
    final examplesJson = map['examples_json'] as String?;
    if (examplesJson != null && examplesJson.isNotEmpty) {
      final list = jsonDecode(examplesJson) as List;
      examples = list
          .map((e) => ExampleSentence.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Backward compat: migrate old single example_sentence field
      final oldSentence = map['example_sentence'] as String?;
      if (oldSentence != null && oldSentence.isNotEmpty) {
        examples = [ExampleSentence(sentence: oldSentence)];
      }
    }
    return Word(
      id: map['id'] as int?,
      english: map['english'] as String,
      chinese: map['chinese'] as String,
      englishExplanation: map['english_explanation'] as String?,
      examples: examples,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Word copyWith({
    int? id,
    String? english,
    String? chinese,
    String? englishExplanation,
    List<ExampleSentence>? examples,
  }) =>
      Word(
        id: id ?? this.id,
        english: english ?? this.english,
        chinese: chinese ?? this.chinese,
        englishExplanation: englishExplanation ?? this.englishExplanation,
        examples: examples ?? this.examples,
        createdAt: createdAt,
      );
}
