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
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE word_books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
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
    await db.delete('words', where: 'word_book_id = ?', whereArgs: [id]);
    await db.delete('word_books', where: 'id = ?', whereArgs: [id]);
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
}
