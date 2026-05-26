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

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _isSearchActive = false;
  List<(Word, String)> _searchResults = [];

  int _totalWords = 0;
  int _recentWords = 0;
  int _avgProficiency = 0;

  @override
  void initState() {
    super.initState();
    _loadWordBooks();
    _searchFocus.addListener(() {
      setState(() => _isSearchActive = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadWordBooks() async {
    final results = await Future.wait([
      _db.getAllWordBooksWithCount(),
      _db.getWordStats(),
    ]);
    final books = results[0] as List<(WordBook, int, int)>;
    final stats = results[1] as ({int total, int recentCount, int avgProficiency});
    setState(() {
      _wordBooks = books;
      _totalWords = stats.total;
      _recentWords = stats.recentCount;
      _avgProficiency = stats.avgProficiency;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _db.searchWords(query.trim());
    if (mounted) setState(() => _searchResults = results);
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    _StatItem(label: '全部單字', value: '$_totalWords'),
                    Container(width: 1, height: 36, color: Colors.grey.shade200),
                    _StatItem(label: '本週新增', value: '$_recentWords'),
                    Container(width: 1, height: 36, color: Colors.grey.shade200),
                    _StatItem(label: '平均熟練度', value: '$_avgProficiency%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: '搜尋單字...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // 單字書列表（永遠存在，搜尋時被遮住）
                  ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _wordBooks.isEmpty ? 1 : _wordBooks.length,
                          itemBuilder: (context, index) {
                            if (_wordBooks.isEmpty) {
                              return const Center(
                                child: Text('還沒有單字書，點 + 新增吧！'),
                              );
                            }
                            final (book, count, avgProficiency) =
                                _wordBooks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Slidable(
                                key: Key('book_${book.id}'),
                                endActionPane: book.isDefault
                                    ? null
                                    : ActionPane(
                                        motion: const DrawerMotion(),
                                        extentRatio: 0.2,
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) =>
                                                _deleteWordBook(book, count),
                                            backgroundColor: AppColors.pinkDark,
                                            foregroundColor: Colors.white,
                                            icon: Icons.delete,
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                              right: Radius.circular(12),
                                            ),
                                          ),
                                        ],
                                      ),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    leading:
                                        const Icon(Icons.menu_book_rounded),
                                    title: Text(
                                      book.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text('$count 個單字'),
                                    trailing: count > 0
                                        ? proficiencyIcon(avgProficiency,
                                            size: 24)
                                        : null,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              WordListScreen(wordBook: book),
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
                  // 搜尋結果浮層
                  if (_isSearchActive) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _searchFocus.unfocus(),
                      child: Container(color: Colors.black26),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Material(
                          elevation: 4,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.5,
                            ),
                            child: _searchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('沒有符合的單字',
                                        style:
                                            TextStyle(color: Colors.grey)),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final (word, bookName) =
                                          _searchResults[index];
                                      return ListTile(
                                        leading: proficiencyIcon(
                                            word.proficiency,
                                            size: 28),
                                        title: Text(word.english),
                                        subtitle: Text(word.chinese),
                                        trailing: Text(
                                          bookName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                        onTap: () async {
                                          _searchFocus.unfocus();
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AddWordScreen(word: word),
                                            ),
                                          );
                                          await _loadWordBooks();
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                  ],
                ],
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
