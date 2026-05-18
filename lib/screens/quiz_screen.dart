import 'dart:math';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/word.dart';

enum _QuizType { enToCn, cnToEn, fillInBlank }

class _Question {
  final Word word;
  final _QuizType type;
  final String prompt;
  final String answer;

  const _Question({
    required this.word,
    required this.type,
    required this.prompt,
    required this.answer,
  });
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _db = DbHelper();
  final _answerCtrl = TextEditingController();
  final _random = Random();

  List<_Question> _questions = [];
  int _current = 0;
  int _correct = 0;
  bool _answered = false;
  bool _isCorrect = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final words = await _db.getRecentWords(20);
    setState(() {
      _questions = _generateQuestions(words);
      _loading = false;
    });
  }

  List<_Question> _generateQuestions(List<Word> words) {
    final shuffled = List<Word>.from(words)..shuffle(_random);
    final questions = <_Question>[];
    for (final word in shuffled.take(10)) {
      final available = [_QuizType.enToCn, _QuizType.cnToEn];
      if (word.exampleSentence != null &&
          word.exampleSentence!
              .toLowerCase()
              .contains(word.english.toLowerCase())) {
        available.add(_QuizType.fillInBlank);
      }
      questions.add(_buildQuestion(word, available[_random.nextInt(available.length)]));
    }
    return questions;
  }

  _Question _buildQuestion(Word word, _QuizType type) {
    switch (type) {
      case _QuizType.enToCn:
        return _Question(
          word: word,
          type: type,
          prompt: word.english,
          answer: word.chinese,
        );
      case _QuizType.cnToEn:
        return _Question(
          word: word,
          type: type,
          prompt: word.chinese,
          answer: word.english,
        );
      case _QuizType.fillInBlank:
        final blanked = word.exampleSentence!.replaceAll(
          RegExp(RegExp.escape(word.english), caseSensitive: false),
          '___',
        );
        return _Question(
          word: word,
          type: type,
          prompt: '${word.chinese}\n\n$blanked',
          answer: word.english,
        );
    }
  }

  void _submit() {
    final correct = _answerCtrl.text.trim().toLowerCase() ==
        _questions[_current].answer.toLowerCase();
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (correct) _correct++;
    });
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      setState(() => _current = _questions.length);
    } else {
      setState(() {
        _current++;
        _answered = false;
        _isCorrect = false;
        _answerCtrl.clear();
      });
    }
  }

  String _questionLabel(_QuizType type) {
    switch (type) {
      case _QuizType.enToCn:
        return '請輸入中文意思：';
      case _QuizType.cnToEn:
        return '請輸入英文單字：';
      case _QuizType.fillInBlank:
        return '請填入缺少的英文單字：';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('複習')),
        body: const Center(child: Text('單字不足，請先新增更多單字。')),
      );
    }

    if (_current >= _questions.length) {
      return _buildResultScreen();
    }

    final question = _questions[_current];
    return Scaffold(
      appBar: AppBar(
        title: Text('複習 ${_current + 1} / ${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _questionLabel(question.type),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _answerCtrl,
              enabled: !_answered,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '你的答案',
                border: const OutlineInputBorder(),
                filled: _answered,
                fillColor: _answered
                    ? (_isCorrect ? Colors.green.shade50 : Colors.red.shade50)
                    : null,
              ),
              onSubmitted: _answered ? null : (_) => _submit(),
            ),
            if (_answered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isCorrect ? '正確！' : '正確答案：${question.answer}',
                    style: TextStyle(
                      color: _isCorrect ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            if (!_answered)
              ElevatedButton(onPressed: _submit, child: const Text('送出'))
            else
              ElevatedButton(
                onPressed: _next,
                child: Text(
                  _current + 1 >= _questions.length ? '查看結果' : '下一題',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final total = _questions.length;
    final percent = _correct / total;
    return Scaffold(
      appBar: AppBar(title: const Text('複習結果')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_correct / $total',
              style: const TextStyle(
                  fontSize: 64, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              percent >= 0.8
                  ? '太棒了！'
                  : percent >= 0.6
                      ? '不錯！繼續加油'
                      : '再多複習幾次吧',
              style: const TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('回到單字本'),
            ),
          ],
        ),
      ),
    );
  }
}
