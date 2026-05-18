import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

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
    final words = await _db.getAllWords();
    setState(() => _words = words);
  }

  Future<void> _deleteWord(int id) async {
    await _db.deleteWord(id);
    await _loadWords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的單字本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadWords();
            },
          ),
        ],
      ),
      body: _words.isEmpty
          ? const Center(
              child: Text(
                '還沒有單字，點 + 新增吧！',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return Dismissible(
                        key: Key('word_${word.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteWord(word.id!),
                        child: ListTile(
                          title: Text(
                            word.english,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(word.chinese),
                          trailing: word.exampleSentence != null
                              ? const Icon(Icons.format_quote,
                                  size: 16, color: Colors.grey)
                              : null,
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
                if (_words.length >= 3)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuizScreen()),
                        ),
                        icon: const Icon(Icons.quiz),
                        label: const Text('開始複習'),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWordScreen()),
          );
          await _loadWords();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
