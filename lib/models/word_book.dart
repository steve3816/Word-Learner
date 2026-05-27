class WordBook {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isDefault;

  const WordBook({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.isDefault = false,
  });

  WordBook copyWith({String? name, String? description}) => WordBook(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        isDefault: isDefault,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_default': isDefault ? 1 : 0,
      };

  factory WordBook.fromMap(Map<String, dynamic> map) => WordBook(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        isDefault: (map['is_default'] as int? ?? 0) == 1,
      );
}
