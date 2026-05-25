import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import '../utils/proficiency_util.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'word_list_screen.dart';

class WordBookListScreen extends StatefulWidget {
  const WordBookListScreen({super.key});

  @override
  State<WordBookListScreen> createState() => _WordBookListScreenState();
}

class _WordBookListScreenState extends State<WordBookListScreen> {
  final _db = DbHelper();
  List<(WordBook, int, int)> _wordBooks = [];

  @override
  void initState() {
    super.initState();
    _loadWordBooks();
  }

  Future<void> _loadWordBooks() async {
    final books = await _db.getAllWordBooksWithCount();
    setState(() => _wordBooks = books);
  }

  Future<void> _openSearchOverlay() async {
    final word = await showGeneralDialog<Word>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉搜尋',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => _SearchOverlay(db: _db),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (word != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddWordScreen(word: word)),
      );
      await _loadWordBooks();
    }
  }

  Future<void> _addWordBook() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增單字書'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '單字書名稱'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('新增'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _db.insertWordBook(
      WordBook(name: name, createdAt: DateTime.now()),
    );
    await _loadWordBooks();
  }

  Future<void> _deleteWordBook(WordBook book, int wordCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除單字書'),
        content: Text(
          wordCount > 0
              ? '刪除「${book.name}」將同時刪除其中 $wordCount 個單字，確定嗎？'
              : '確定刪除「${book.name}」嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteWordBook(book.id!);
    await _loadWordBooks();
  }

  int get _totalWordCount => _wordBooks.fold(0, (sum, e) => sum + e.$2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('單字書'),
        actions: [
          if (_totalWordCount >= 3)
            IconButton(
              icon: const Icon(Icons.quiz),
              tooltip: '複習全部單字',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: DotGridBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                readOnly: true,
                onTap: _openSearchOverlay,
                decoration: InputDecoration(
                  hintText: '搜尋單字...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _wordBooks.isEmpty
                  ? const Center(child: Text('還沒有單字書，點 + 新增吧！'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _wordBooks.length,
                      itemBuilder: (context, index) {
                        final (book, count, avgProficiency) = _wordBooks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Slidable(
                            key: Key('book_${book.id}'),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: 0.2,
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteWordBook(book, count),
                                  backgroundColor: AppColors.pinkDark,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(12),
                                  ),
                                ),
                              ],
                            ),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: const Icon(Icons.menu_book_rounded),
                                title: Text(
                                  book.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('$count 個單字'),
                                trailing: count > 0
                                    ? proficiencyIcon(avgProficiency, size: 24)
                                    : null,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WordListScreen(wordBook: book),
                                    ),
                                  );
                                  await _loadWordBooks();
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: GradientFAB(
        onPressed: _addWordBook,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SearchOverlay extends StatefulWidget {
  final DbHelper db;
  const _SearchOverlay({required this.db});

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _ctrl = TextEditingController();
  List<(Word, String)> _results = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final results = await widget.db.searchWords(query.trim());
    if (mounted) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        elevation: 8,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜尋單字...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _ctrl.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _search,
                ),
              ),
              if (_ctrl.text.isNotEmpty && _results.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('沒有符合的單字', style: TextStyle(color: Colors.grey)),
                ),
              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final (word, bookName) = _results[index];
                      return ListTile(
                        leading: proficiencyIcon(word.proficiency, size: 28),
                        title: Text(word.english),
                        subtitle: Text(word.chinese),
                        trailing: Text(
                          bookName,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () => Navigator.pop(context, word),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
