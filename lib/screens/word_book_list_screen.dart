import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word_book.dart';
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
  List<(WordBook, int)> _wordBooks = [];

  @override
  void initState() {
    super.initState();
    _loadWordBooks();
  }

  Future<void> _loadWordBooks() async {
    final books = await _db.getAllWordBooksWithCount();
    setState(() => _wordBooks = books);
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
        child: _wordBooks.isEmpty
            ? const Center(child: Text('還沒有單字書，點 + 新增吧！'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _wordBooks.length,
                itemBuilder: (context, index) {
                  final (book, count) = _wordBooks[index];
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
      floatingActionButton: GradientFAB(
        onPressed: _addWordBook,
        child: const Icon(Icons.add),
      ),
    );
  }
}
