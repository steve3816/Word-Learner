class WordBook {
  final int? id;
  final String name;
  final DateTime createdAt;

  const WordBook({this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WordBook.fromMap(Map<String, dynamic> map) => WordBook(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
