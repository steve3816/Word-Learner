import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';
import '../models/word_book.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._();
  static Database? _db;

  DbHelper._();
  factory DbHelper() => _instance;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'vocab.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE word_books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.insert('word_books', {
          'name': '我的單字書',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'is_default': 1,
        });
        await db.execute('''
          CREATE TABLE words(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            english TEXT NOT NULL,
            chinese TEXT NOT NULL,
            english_explanation TEXT,
            examples_json TEXT,
            created_at INTEGER NOT NULL,
            word_book_id INTEGER NOT NULL,
            proficiency INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE words ADD COLUMN english_explanation TEXT');
          await db.execute('ALTER TABLE words ADD COLUMN examples_json TEXT');
          final rows = await db.query('words', columns: ['id', 'example_sentence']);
          for (final row in rows) {
            final old = row['example_sentence'] as String?;
            if (old != null && old.isNotEmpty) {
              final json = jsonEncode([
                {'sentence': old, 'chineseTranslation': null}
              ]);
              await db.update(
                'words',
                {'examples_json': json},
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE word_books(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.insert('word_books', {
            'name': '我的單字書',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
          await db.execute(
            'ALTER TABLE words ADD COLUMN word_book_id INTEGER DEFAULT 1',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE words ADD COLUMN proficiency INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE word_books ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0',
          );
          // 把已存在的「我的單字書」標為預設；若已刪除則建一個新的
          final rows = await db.query(
            'word_books',
            where: "name = '我的單字書'",
            limit: 1,
          );
          if (rows.isNotEmpty) {
            await db.update(
              'word_books',
              {'is_default': 1},
              where: 'id = ?',
              whereArgs: [rows.first['id']],
            );
          } else {
            await db.insert('word_books', {
              'name': '我的單字書',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'is_default': 1,
            });
          }
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE word_books ADD COLUMN description TEXT');
        }
      },
    );
  }

  // ── Word Book ────────────────────────────────────────────
  Future<int> insertWordBook(WordBook book) async {
    final db = await database;
    return db.insert('word_books', book.toMap());
  }

  Future<void> updateWordBook(WordBook book) async {
    final db = await database;
    await db.update('word_books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  Future<void> deleteWordBook(int id) async {
    final db = await database;
    final rows = await db.query('word_books',
        columns: ['is_default'], where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty && (rows.first['is_default'] as int) == 1) return;
    await db.delete('words', where: 'word_book_id = ?', whereArgs: [id]);
    await db.delete('word_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<WordBook?> getDefaultWordBook() async {
    final db = await database;
    final rows =
        await db.query('word_books', where: 'is_default = 1', limit: 1);
    return rows.isEmpty ? null : WordBook.fromMap(rows.first);
  }

  Future<List<(WordBook, int, int)>> getAllWordBooksWithCount() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT wb.*, COUNT(w.id) as word_count,
             COALESCE(CAST(AVG(w.proficiency) AS INTEGER), 0) as avg_proficiency
      FROM word_books wb
      LEFT JOIN words w ON w.word_book_id = wb.id
      GROUP BY wb.id
      ORDER BY wb.created_at DESC
    ''');
    return rows.map((row) {
      final book = WordBook.fromMap(row);
      final count = row['word_count'] as int;
      final avgProficiency = row['avg_proficiency'] as int;
      return (book, count, avgProficiency);
    }).toList();
  }

  // ── Word ─────────────────────────────────────────────────
  Future<int> insertWord(Word word) async {
    final db = await database;
    return db.insert('words', word.toMap());
  }

  Future<void> updateWord(Word word) async {
    final db = await database;
    await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deleteWord(int id) async {
    final db = await database;
    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final maps = await db.query('words', orderBy: 'created_at DESC');
    return maps.map(Word.fromMap).toList();
  }

  Future<List<Word>> getWordsByWordBook(int wordBookId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'word_book_id = ?',
      whereArgs: [wordBookId],
      orderBy: 'created_at DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<({int total, int recentCount, int avgProficiency})> getWordStats() async {
    final db = await database;
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) as recent,
        COALESCE(CAST(ROUND(AVG(CAST(proficiency AS REAL))) AS INTEGER), 0) as avg_prof
      FROM words
    ''', [weekAgo]);
    final row = rows.first;
    return (
      total: row['total'] as int,
      recentCount: (row['recent'] as int?) ?? 0,
      avgProficiency: row['avg_prof'] as int,
    );
  }

  Future<List<(Word, String)>> searchWords(String query) async {
    final db = await database;
    final pattern = '%$query%';
    final rows = await db.rawQuery('''
      SELECT w.*, wb.name as book_name
      FROM words w
      JOIN word_books wb ON w.word_book_id = wb.id
      WHERE w.english LIKE ? OR w.chinese LIKE ?
      ORDER BY w.english ASC
      LIMIT 30
    ''', [pattern, pattern]);
    return rows.map((row) {
      final word = Word.fromMap(row);
      final bookName = row['book_name'] as String;
      return (word, bookName);
    }).toList();
  }
}
