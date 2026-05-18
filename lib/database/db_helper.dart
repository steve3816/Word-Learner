import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

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
      version: 2,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE words(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          english TEXT NOT NULL,
          chinese TEXT NOT NULL,
          english_explanation TEXT,
          examples_json TEXT,
          created_at INTEGER NOT NULL
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE words ADD COLUMN english_explanation TEXT');
          await db.execute('ALTER TABLE words ADD COLUMN examples_json TEXT');
          // Migrate old example_sentence data into examples_json format
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
      },
    );
  }

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

  Future<List<Word>> getRecentWords(int count) async {
    final db = await database;
    final maps = await db.query('words', orderBy: 'created_at DESC', limit: count);
    return maps.map(Word.fromMap).toList();
  }
}
