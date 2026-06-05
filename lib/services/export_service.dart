import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/example_sentence.dart';
import '../models/word.dart';
import '../models/word_book.dart';

class ImportPreview {
  final String fileName;
  final int wordBookCount;
  final int wordCount;
  final Map<String, dynamic> _raw;

  const ImportPreview._({
    required this.fileName,
    required this.wordBookCount,
    required this.wordCount,
    required Map<String, dynamic> raw,
  }) : _raw = raw;

  List<String> get bookNames => (_raw['wordBooks'] as List<dynamic>)
      .map((b) => (b as Map<String, dynamic>)['name'] as String)
      .toList();
}

class ExportService {
  final _db = DbHelper();

  Future<void> exportAll() async {
    final rows = await _db.getAllWordBooksWithCount();
    final books = rows.map((r) => r.$1).toList();
    await _shareJson(await _buildJson(books));
  }

  Future<void> exportWordBook(WordBook book) async {
    await _shareJson(await _buildJson([book]));
  }

  // Step 1: pick file and return preview. Returns null if cancelled.
  Future<ImportPreview?> pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final path = result.files.single.path!;
    final content = await File(path).readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    if (data['version'] != 1) throw Exception('不支援此版本的匯出格式');

    final wordBooks = data['wordBooks'] as List<dynamic>;
    final wordCount = wordBooks.fold<int>(
      0,
      (sum, b) => sum + ((b as Map<String, dynamic>)['words'] as List).length,
    );

    return ImportPreview._(
      fileName: result.files.single.name,
      wordBookCount: wordBooks.length,
      wordCount: wordCount,
      raw: data,
    );
  }

  // Step 2: actually write to database.
  Future<void> importData(ImportPreview preview) async {
    final wordBooks = preview._raw['wordBooks'] as List<dynamic>;
    for (final bookJson in wordBooks) {
      final book = bookJson as Map<String, dynamic>;
      final bookId = await _db.insertWordBook(WordBook(
        name: book['name'] as String,
        description: book['description'] as String?,
        createdAt: DateTime.now(),
      ));
      final words = book['words'] as List<dynamic>;
      for (final wordJson in words) {
        final w = wordJson as Map<String, dynamic>;
        final examples = (w['examples'] as List<dynamic>?)
                ?.map((e) => ExampleSentence(
                      sentence: e['sentence'] as String,
                      chineseTranslation: e['chineseTranslation'] as String?,
                    ))
                .toList() ??
            [];
        await _db.insertWord(Word(
          english: w['english'] as String,
          chinese: w['chinese'] as String,
          englishExplanation: w['englishExplanation'] as String?,
          examples: examples,
          proficiency: 0,
          createdAt: DateTime.now(),
          wordBookId: bookId,
        ));
      }
    }
  }

  Future<Map<String, dynamic>> _buildJson(List<WordBook> books) async {
    final wordBooksJson = <Map<String, dynamic>>[];
    for (final book in books) {
      final words = await _db.getWordsByWordBook(book.id!);
      wordBooksJson.add({
        'name': book.name,
        if (book.description != null) 'description': book.description,
        'words': words.map((w) => {
          'english': w.english,
          'chinese': w.chinese,
          if (w.englishExplanation != null)
            'englishExplanation': w.englishExplanation,
          'examples': w.examples.map((e) => {
            'sentence': e.sentence,
            if (e.chineseTranslation != null)
              'chineseTranslation': e.chineseTranslation,
          }).toList(),
        }).toList(),
      });
    }
    return {'version': 1, 'wordBooks': wordBooksJson};
  }

  Future<void> _shareJson(Map<String, dynamic> data) async {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vocabulary_export.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '單字書匯出'),
    );
  }
}
