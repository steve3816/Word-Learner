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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wordBook.name),
        actions: [
          if (_words.length >= 3)
            IconButton(
              icon: const Icon(Icons.quiz),
              tooltip: '複習此單字書',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(wordBookId: widget.wordBook.id),
                ),
              ),
            ),
        ],
      ),
      body: DotGridBackground(
        child: _words.isEmpty
            ? const Center(child: Text('還沒有單字，點 + 新增吧！'))
            : ListView.builder(
                itemCount: _words.length,
                itemBuilder: (context, index) {
                  final word = _words[index];
                  return Slidable(
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
                  );
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
