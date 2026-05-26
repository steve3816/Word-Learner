class WordBook {
  final int? id;
  final String name;
  final DateTime createdAt;
  final bool isDefault;

  const WordBook({
    this.id,
    required this.name,
    required this.createdAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_default': isDefault ? 1 : 0,
      };

  factory WordBook.fromMap(Map<String, dynamic> map) => WordBook(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        isDefault: (map['is_default'] as int? ?? 0) == 1,
      );
}
