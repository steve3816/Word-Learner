import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../utils/list_util.dart';
import '../utils/proficiency_util.dart';

// 複習題目類型
enum _QuizType {
  enToCn, // 英文提示，填中文
  cnToEn, // 中文提示，填英文
  fillInBlank, // 例句提示，填英文
  enDefinition, // 英文解釋提示，填英文
}

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
  final int? wordBookId;

  const QuizScreen({super.key, this.wordBookId});

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
  int? _pendingProficiency;
  bool _showProficiencyOverride = false;

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
    final words = widget.wordBookId != null
        ? await _db.getWordsByWordBook(widget.wordBookId!)
        : await _db.getAllWords();
    setState(() {
      _questions = _generateQuestions(words);
      _loading = false;
    });
  }

  List<_Question> _generateQuestions(List<Word> words) {
    // 從單字列表中隨機選擇10個，並為每個單字隨機生成一種題型
    return (List<Word>.from(words)..shuffle(_random))
        .take(10)
        .map((word) {

          bool hasExample = word.exampleSentence != null &&
                word.exampleSentence!
                    .toLowerCase()
                  .contains(word.english.toLowerCase());

          final availableQuizType = [
            _QuizType.enToCn,
            _QuizType.cnToEn,
            if (hasExample) _QuizType.fillInBlank,
            if (word.englishExplanation != null) _QuizType.enDefinition,
          ];

          return _buildQuestion(word, ListUtil.getRandomElement(availableQuizType, _random));
        })
        .toList();
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
      case _QuizType.enDefinition:
        return _Question(
          word: word,
          type: type,
          prompt: word.englishExplanation!,
          answer: word.english,
        );
      case _QuizType.fillInBlank:
        final exampleSentence = ListUtil.getRandomElement(word.examples, _random);
        final blankedExamepleSentence = exampleSentence.sentence.replaceAll(
          RegExp(RegExp.escape(word.english), caseSensitive: false),
          '___',
        );
        final translation = exampleSentence.chineseTranslation;
        return _Question(
          word: word,
          type: type,
          prompt: translation != null ? '$translation\n\n$blankedExamepleSentence' : blankedExamepleSentence,
          answer: word.english,
        );

    }
  }

  void _submit() {
    final word = _questions[_current].word;
    final correct = _answerCtrl.text.trim().toLowerCase() ==
        _questions[_current].answer.toLowerCase();
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (correct) _correct++;
      _pendingProficiency = (word.proficiency + (correct ? 10 : -10)).clamp(0, 100);
    });
  }

  void _next() {
    _db.updateWord(_questions[_current].word.copyWith(proficiency: _pendingProficiency!));
    if (_current + 1 >= _questions.length) {
      setState(() {
        _current = _questions.length;
        _pendingProficiency = null;
        _showProficiencyOverride = false;
      });
    } else {
      setState(() {
        _current++;
        _answered = false;
        _isCorrect = false;
        _pendingProficiency = null;
        _showProficiencyOverride = false;
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
      case _QuizType.enDefinition:
        return '根據英文解釋，填入對應的英文單字：';
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
        body: const DotGridBackground(
          child: Center(child: Text('單字不足，請先新增更多單字。')),
        ),
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
      body: DotGridBackground(
        child: Padding(
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
                readOnly: _answered,
                autofocus: true,
                style: _answered
                    ? TextStyle(color: Colors.grey.shade500)
                    : null,
                decoration: InputDecoration(
                  labelText: '你的答案',
                  filled: _answered,
                  fillColor: _answered ? Colors.grey.shade100 : null,
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
                    Expanded(
                      child: Text(
                        _isCorrect ? '正確！' : '正確答案：${question.answer}',
                        style: TextStyle(
                          color: _isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(
                        () => _showProficiencyOverride = !_showProficiencyOverride,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('熟練度：', style: TextStyle(fontSize: 13)),
                          Icon(
                            _isCorrect ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: _isCorrect ? const Color.fromARGB(255, 1, 147, 11) : const Color.fromARGB(255, 255, 0, 0),
                          ),
                          const SizedBox(width: 4),
                          proficiencyIcon(_pendingProficiency!, size: 24),
                          const SizedBox(width: 2),
                          Icon(
                            _showProficiencyOverride
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showProficiencyOverride) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: proficiencyLevels.map((level) {
                      final isSelected = proficiencyToLevel(_pendingProficiency!) == level.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _pendingProficiency = level.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              SvgPicture.asset(
                                proficiencyAsset(level.$1),
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(level.$2, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
              const Spacer(),
              if (!_answered)
                GradientButton(onPressed: _submit, child: const Text('送出'))
              else
                GradientButton(
                  onPressed: _next,
                  child: Text(
                    _current + 1 >= _questions.length ? '查看結果' : '下一題',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final total = _questions.length;
    final percent = _correct / total;
    return Scaffold(
      appBar: AppBar(title: const Text('複習結果')),
      body: DotGridBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$_correct / $total',
                style: const TextStyle(
                    fontSize: 64, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                percent >= 0.8
                    ? '太棒了！'
                    : percent >= 0.6
                        ? '不錯！繼續加油'
                        : '再多複習幾次吧',
                style: const TextStyle(fontSize: 20, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GradientButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('回到單字本'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
