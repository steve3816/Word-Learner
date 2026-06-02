import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import '../utils/proficiency_util.dart';
import '../services/widget_service.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';

class WordListScreen extends StatefulWidget {
  final WordBook wordBook;

  const WordListScreen({super.key, required this.wordBook});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final _db = DbHelper();
  List<Word> _words = [];
  late WordBook _wordBook;

  @override
  void initState() {
    super.initState();
    _wordBook = widget.wordBook;
    _loadWords();
  }

  Future<void> _loadWords() async {
    final words = await _db.getWordsByWordBook(widget.wordBook.id!);
    setState(() => _words = words);
  }

  Future<void> _deleteWord(int id) async {
    await _db.deleteWord(id);
    WidgetService.syncWords();
    await _loadWords();
  }

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inHours < 24) {
      return '${diff.inHours == 0 ? 1 : diff.inHours}小時內';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天內';
    } else if (diff.inDays < 14) {
      return '1禮拜';
    } else {
      return '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _editWordBook() async {
    final nameCtrl = TextEditingController(text: _wordBook.name);
    final descCtrl = TextEditingController(text: _wordBook.description ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('單字書設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名稱'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '描述（選填）'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result != true || nameCtrl.text.trim().isEmpty) return;
    final updated = _wordBook.copyWith(
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );
    await _db.updateWordBook(updated);
    if (mounted) setState(() => _wordBook = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_wordBook.name),
        actions: [
          if (_words.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_edu),
              tooltip: '複習此單字書',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(wordBookId: widget.wordBook.id),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '單字書設定',
            onPressed: _editWordBook,
          ),
        ],
      ),
      body: DotGridBackground(
        child: _words.isEmpty
            ? const Center(child: Text('還沒有單字，點 + 新增吧！'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _words.length,
                itemBuilder: (context, index) {
                  final word = _words[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2A2530).withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Container(width: 3, color: AppColors.purpleDark),
                            Expanded(child: Slidable(
                          key: Key('word_${word.id}'),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.2,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _deleteWord(word.id!),
                                backgroundColor: AppColors.pinkDark,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(word.english),
                            subtitle: Text(word.chinese),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatCreatedAt(word.createdAt),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                proficiencyIcon(word.proficiency, size: 22),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddWordScreen(word: word),
                                ),
                              );
                              await _loadWords();
                            },
                          ),
                        )),      // Slidable, Expanded
                          ],
                        ),       // Row
                      ),         // ClipRRect
                    ),           // DecoratedBox
                  );             // Padding
                },
              ),
      ),
      floatingActionButton: GradientFAB(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddWordScreen(wordBookId: widget.wordBook.id!),
            ),
          );
          await _loadWords();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
