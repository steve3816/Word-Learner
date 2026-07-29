import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/example_sentence.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import 'settings_service.dart';

class ImportPreview {
  final String fileName;
  final int wordBookCount;
  final int wordCount;
  final bool hasPrompts;
  final Map<String, dynamic> _raw;

  const ImportPreview._({
    required this.fileName,
    required this.wordBookCount,
    required this.wordCount,
    required this.hasPrompts,
    required Map<String, dynamic> raw,
  }) : _raw = raw;

  List<String> get bookNames => (_raw['wordBooks'] as List<dynamic>)
      .map((b) => (b as Map<String, dynamic>)['name'] as String)
      .toList();

  Map<String, String>? get prompts {
    final p = _raw['prompts'];
    if (p == null) return null;
    return Map<String, String>.from(p as Map<String, dynamic>);
  }
}

class ExportService {
  final _db = DbHelper();
  final _settings = SettingsService();

  Future<void> exportAll({bool includePrompts = false}) async {
    final rows = await _db.getAllWordBooksWithCount();
    final books = rows.map((r) => r.$1).toList();
    await _shareJson(await _buildJson(books, includePrompts: includePrompts));
  }

  Future<void> saveAll({bool includePrompts = false}) async {
    final rows = await _db.getAllWordBooksWithCount();
    final books = rows.map((r) => r.$1).toList();
    await _saveJson(await _buildJson(books, includePrompts: includePrompts));
  }

  Future<void> exportWordBook(WordBook book,
      {bool includePrompts = false}) async {
    await _shareJson(await _buildJson([book], includePrompts: includePrompts));
  }

  Future<void> saveWordBook(WordBook book,
      {bool includePrompts = false}) async {
    await _saveJson(await _buildJson([book], includePrompts: includePrompts));
  }

  // Step 1: pick file and return preview. Returns null if cancelled.
  Future<ImportPreview?> pickAndPreview() async {
    // 不用 FileType.custom + allowedExtensions：部分 Android 檔案來源回報的
    // MIME type 跟副檔名對不上，用系統的 MIME 篩選會讓檔案變成灰色點不下去。
    // 改成選完之後自己檢查檔名副檔名，一樣能擋掉選錯檔案的情況。
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return null;

    if (!result.files.single.name.toLowerCase().endsWith('.json')) {
      throw Exception('請選擇 .json 格式的匯出檔案');
    }

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
      hasPrompts: data.containsKey('prompts'),
      raw: data,
    );
  }

  // Step 2: actually write to database, optionally apply prompts.
  Future<void> importData(ImportPreview preview,
      {bool importPrompts = false}) async {
    if (importPrompts && preview.prompts != null) {
      await _settings.setAllPrompts(preview.prompts!);
    }

    final wordBooks = preview._raw['wordBooks'] as List<dynamic>;
    final idxToNewId = <int, int>{};
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
        final newId = await _db.insertWord(Word(
          english: w['english'] as String,
          chinese: w['chinese'] as String,
          englishExplanation: w['englishExplanation'] as String?,
          notes: w['notes'] as String?,
          examples: examples,
          proficiency: 0,
          createdAt: DateTime.now(),
          wordBookId: bookId,
        ));
        final idx = w['idx'] as int?;
        if (idx != null) idxToNewId[idx] = newId;
      }
    }

    // 用匯出時附加的暫時索引，把關聯字的配對從舊索引換成剛插入後拿到的新 id。
    final relations = preview._raw['wordRelations'] as List<dynamic>?;
    if (relations != null) {
      for (final pair in relations) {
        final indices = (pair as List<dynamic>).cast<int>();
        final idA = idxToNewId[indices[0]];
        final idB = idxToNewId[indices[1]];
        if (idA != null && idB != null) {
          await _db.addWordRelations(idA, [idB]);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _buildJson(List<WordBook> books,
      {bool includePrompts = false}) async {
    final wordBooksJson = <Map<String, dynamic>>[];
    // 關聯字存在資料庫裡是靠 id 對應，但匯入時每個字都會拿到全新的 id，
    // 所以先給每個匯出的字一個只在這份檔案裡有意義的暫時索引，關聯字改用索引表示。
    final idToIndex = <int, int>{};
    var index = 0;

    for (final book in books) {
      final words = await _db.getWordsByWordBook(book.id!);
      final wordsJson = <Map<String, dynamic>>[];
      for (final w in words) {
        idToIndex[w.id!] = index;
        wordsJson.add({
          'idx': index,
          'english': w.english,
          'chinese': w.chinese,
          if (w.englishExplanation != null)
            'englishExplanation': w.englishExplanation,
          if (w.notes != null) 'notes': w.notes,
          'examples': w.examples
              .map((e) => {
                    'sentence': e.sentence,
                    if (e.chineseTranslation != null)
                      'chineseTranslation': e.chineseTranslation,
                  })
              .toList(),
        });
        index++;
      }
      wordBooksJson.add({
        'name': book.name,
        if (book.description != null) 'description': book.description,
        'words': wordsJson,
      });
    }

    final relationPairs = <List<int>>[];
    final seenPairs = <String>{};
    for (final id in idToIndex.keys) {
      final related = await _db.getRelatedWords(id);
      final thisIdx = idToIndex[id]!;
      for (final r in related) {
        final otherIdx = idToIndex[r.id]!;
        final a = thisIdx < otherIdx ? thisIdx : otherIdx;
        final b = thisIdx < otherIdx ? otherIdx : thisIdx;
        if (seenPairs.add('$a-$b')) {
          relationPairs.add([a, b]);
        }
      }
    }

    final json = <String, dynamic>{'version': 1};
    if (includePrompts) {
      json['prompts'] = await _settings.getAllPrompts();
    }
    json['wordBooks'] = wordBooksJson;
    if (relationPairs.isNotEmpty) {
      json['wordRelations'] = relationPairs;
    }
    return json;
  }

  Future<void> _saveJson(Map<String, dynamic> data) async {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(json));
    await FilePicker.platform.saveFile(
      dialogTitle: '選擇儲存位置',
      fileName: 'haword_export.json',
      bytes: bytes,
    );
  }

  Future<void> _shareJson(Map<String, dynamic> data) async {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/haword_export.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '單字書匯出'),
    );
  }
}
