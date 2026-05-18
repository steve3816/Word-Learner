class Word {
  final int? id;
  final String english;
  final String chinese;
  final String? exampleSentence;
  final DateTime createdAt;

  const Word({
    this.id,
    required this.english,
    required this.chinese,
    this.exampleSentence,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'english': english,
        'chinese': chinese,
        'example_sentence': exampleSentence,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: map['id'] as int?,
        english: map['english'] as String,
        chinese: map['chinese'] as String,
        exampleSentence: map['example_sentence'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Word copyWith({
    int? id,
    String? english,
    String? chinese,
    String? exampleSentence,
  }) =>
      Word(
        id: id ?? this.id,
        english: english ?? this.english,
        chinese: chinese ?? this.chinese,
        exampleSentence: exampleSentence ?? this.exampleSentence,
        createdAt: createdAt,
      );
}
