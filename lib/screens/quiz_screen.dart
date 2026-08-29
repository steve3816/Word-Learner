import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/example_sentence.dart';
import '../models/word.dart';
import '../services/ad_service.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../utils/list_util.dart';
import '../utils/proficiency_util.dart';
import '../widgets/shared/banner_ad_widget.dart';

enum _QuizType { enToCn, cnToEn, fillInBlank, enDefinition, aiFillInBlank }

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

class _QuizResult {
  final _Question question;
  final bool isCorrect;
  final int oldProficiency;
  final int newProficiency;
  final String userAnswer;

  const _QuizResult({
    required this.question,
    required this.isCorrect,
    required this.oldProficiency,
    required this.newProficiency,
    required this.userAnswer,
  });

  int get delta => newProficiency - oldProficiency;
}

class QuizScreen extends StatefulWidget {
  final int? wordBookId;

  const QuizScreen({super.key, this.wordBookId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _db = DbHelper();
  final _settings = SettingsService();
  final _answerCtrl = TextEditingController();
  final _answerFocus = FocusNode();
  final _random = Random();

  List<_Question> _questions = [];
  final List<_QuizResult> _results = [];
  int _current = 0;
  int _correct = 0;
  bool _answered = false;
  bool _isCorrect = false;
  bool _loading = true;
  bool _awaitingAd = false;

  AiService? _aiService;
  String? _aiQuizPromptTemplate;

  final _confettiController = ConfettiController(
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _answerFocus.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// 廣告顯示在複習「開始」的那一刻（而不是結束離開時）：進入這個畫面只有一個入口，
  /// 不像離開有返回鍵、手勢等多種路徑都要攔截，天然不會有廣告被繞過的問題。
  ///
  /// 只有輪到該播的那一次才即時去載入廣告並等待——不常駐預載，因為這件事本來就
  /// 只偶爾發生一次，使用者等一下廣告載入是可以接受的；載入失敗（含沒網路）就
  /// 直接放棄，不擋使用者進複習。
  Future<void> _maybeShowInterstitialOnStart() async {
    final due = await AdService.recordQuizStart();
    if (!due || await AdService.isAdFree()) return;
    if (mounted) setState(() => _awaitingAd = true);
    await AdService.ensureInitialized();

    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future;
  }

  Future<void> _init() async {
    final all = widget.wordBookId != null
        ? await _db.getWordsByWordBook(widget.wordBookId!)
        : await _db.getAllWords();
    final maxProficiency = await _settings.getQuizMaxProficiency();
    final words = all
        .where((w) => w.proficiency <= maxProficiency && !w.excludeFromQuiz)
        .toList();

    if (await _settings.getAiQuizEnabled()) {
      _aiService = await _settings.getActiveService();
      if (_aiService != null) {
        _aiQuizPromptTemplate = await _settings.getPrompt('aiQuiz');
      }
    }

    final questions = await _generateQuestions(words);

    await _maybeShowInterstitialOnStart();

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _loading = false;
      _awaitingAd = false;
    });
  }

  Future<List<_Question>> _generateQuestions(List<Word> words) async {
    final selected = (List<Word>.from(words)..shuffle(_random)).take(10);
    final aiAvailable = _aiService != null && _aiQuizPromptTemplate != null;
    final questions = <_Question>[];

    for (final word in selected) {
      final hasBlankableExample = word.examples.any(
        (ex) => ex.sentence.toLowerCase().contains(word.english.toLowerCase()),
      );
      final availableTypes = [
        _QuizType.enToCn,
        _QuizType.cnToEn,
        if (hasBlankableExample) _QuizType.fillInBlank,
        if (word.englishExplanation != null) _QuizType.enDefinition,
        if (aiAvailable && !word.excludeFromAiQuiz) _QuizType.aiFillInBlank,
      ];

      var type = ListUtil.getRandomElement(availableTypes, _random);

      if (type == _QuizType.aiFillInBlank) {
        final aiSentence = await _tryGenerateAiQuizSentence(word);
        if (aiSentence != null) {
          questions.add(_buildQuestion(word, type, aiSentence: aiSentence));
          continue;
        }
        // API 失敗，或句子沒包含這個單字：放棄這次 AI 出題，從候選題型移除後重抽。
        availableTypes.remove(_QuizType.aiFillInBlank);
        type = ListUtil.getRandomElement(availableTypes, _random);
      }

      questions.add(_buildQuestion(word, type));
    }

    return questions;
  }

  /// 準備 AI 出題用的例句，失敗（含沒網路）或句子沒包含目標單字都回傳 null，
  /// 由呼叫端改用其他題型，不會讓整場複習失敗。
  Future<ExampleSentence?> _tryGenerateAiQuizSentence(Word word) async {
    try {
      final prompt =
          _aiQuizPromptTemplate!.replaceAll(
            SettingsService.wordPlaceholder,
            word.english,
          ) +
          ExampleSentence.jsonFormatSuffix;
      final raw = await _aiService!.complete(prompt);
      final result = ExampleSentence.parseJson(raw);
      if (!result.sentence.toLowerCase().contains(word.english.toLowerCase())) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  String _blankedPrompt(Word word, ExampleSentence ex) {
    final blanked = ex.sentence.replaceAll(
      RegExp(RegExp.escape(word.english), caseSensitive: false),
      '___',
    );
    return ex.chineseTranslation != null
        ? '${ex.chineseTranslation}\n\n$blanked'
        : blanked;
  }

  _Question _buildQuestion(
    Word word,
    _QuizType type, {
    ExampleSentence? aiSentence,
  }) {
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
        final blankable = word.examples
            .where(
              (ex) => ex.sentence.toLowerCase().contains(
                word.english.toLowerCase(),
              ),
            )
            .toList();
        final ex = ListUtil.getRandomElement(blankable, _random);
        return _Question(
          word: word,
          type: type,
          prompt: _blankedPrompt(word, ex),
          answer: word.english,
        );
      case _QuizType.aiFillInBlank:
        return _Question(
          word: word,
          type: type,
          prompt: _blankedPrompt(word, aiSentence!),
          answer: word.english,
        );
    }
  }

  void _submit() {
    final word = _questions[_current].word;
    final userInput = _answerCtrl.text.trim().toLowerCase();
    final acceptedAnswers = _questions[_current].answer
        .split(RegExp(r'[；;，,]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);
    final correct =
        acceptedAnswers.any((a) => a == userInput) ||
        userInput == _questions[_current].answer.trim().toLowerCase();
    final newProficiency = (word.proficiency + (correct ? 10 : -10)).clamp(
      ProficiencyLevel.veryUnfamiliar.score,
      ProficiencyLevel.proficient.score,
    );
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (correct) _correct++;
      _results.add(
        _QuizResult(
          question: _questions[_current],
          isCorrect: correct,
          oldProficiency: word.proficiency,
          newProficiency: newProficiency,
          userAnswer: _answerCtrl.text.trim(),
        ),
      );
    });
  }

  void _next() {
    _answerFocus.unfocus();
    if (_current + 1 >= _questions.length) {
      for (final r in _results) {
        _db.updateWord(r.question.word.copyWith(proficiency: r.newProficiency));
      }
      setState(() => _current = _questions.length);
      if (_correct / _questions.length >= 0.8) {
        _confettiController.play();
      }
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
        return '請根據翻譯輸入英文單字：';
      case _QuizType.enDefinition:
        return '根據英文解釋，填入對應的英文單字：';
      case _QuizType.fillInBlank:
      case _QuizType.aiFillInBlank:
        return '請填入缺少的英文單字：';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (_awaitingAd) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.shrink(),
        );
      }
      return const Scaffold(body: Center(child: _PreparingIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('複習')),
        body: const DotGridBackground(
          child: Center(child: Text('單字不足或單字熟練度高於複習設定')),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('使用說明'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '複習會從熟練度未達到「設定」中「複習出題熟練度範圍」上限的單字中出題，題型隨機包含英翻中、中翻英、英文解釋猜單字、例句填空。',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '以下情況將使該欄位不納入出題範圍：',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _QuizInfoItem(
                        icon: Icons.close,
                        text: '例句填空：不包含英文單字原形的例句',
                      ),
                      const SizedBox(height: 12),
                      const _QuizInfoItem(
                        icon: Icons.close,
                        text: '英文解釋：未填寫英文解釋',
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('了解'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                  child: question.type == _QuizType.enDefinition
                      ? Column(
                          children: [
                            Text(
                              question.prompt,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _speakerBtn(question.prompt),
                            ),
                          ],
                        )
                      : Text(
                          question.prompt,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _answerCtrl,
                focusNode: _answerFocus,
                readOnly: _answered,
                style: _answered
                    ? TextStyle(color: Colors.grey.shade500)
                    : null,
                decoration: InputDecoration(
                  labelText: '你的答案',
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                  ],
                ),
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

  Widget _speakerBtn(String text, {double size = 26, double iconSize = 13}) =>
      Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => TtsService.instance.speak(text),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.volume_up_rounded,
              size: iconSize,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );

  Widget _buildResultScreen() {
    final total = _questions.length;
    final percent = _correct / total;
    return Scaffold(
      appBar: AppBar(title: const Text('複習結果')),
      body: Stack(
        children: [
          DotGridBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text(
                  '$_correct / $total',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  percent >= 0.8
                      ? '太棒了！'
                      : percent >= 0.6
                      ? '不錯！繼續加油'
                      : '再多複習幾次吧',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (final result in _results) _buildResultRow(result),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('回到單字本'),
                ),
                const SizedBox(height: 16),
                const Center(child: BannerAdWidget()),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 60,
              minBlastForce: 10,
              maxBlastForce: 30,
              minimumSize: const Size(3, 3),
              maximumSize: const Size(8, 5),
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(_QuizResult result) {
    final deltaColor = result.isCorrect ? Colors.green : Colors.red;
    final deltaText = result.isCorrect ? '+10' : '-10';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A2530).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                result.isCorrect ? Icons.check_circle : Icons.cancel,
                color: result.isCorrect ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.question.word.english,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      result.question.word.chinese,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (!result.isCorrect) ...[
                      const SizedBox(height: 4),
                      Text(
                        '你的答案：${result.userAnswer}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(
                  begin: result.oldProficiency,
                  end: result.newProficiency,
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (_, value, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$value%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      deltaText,
                      style: TextStyle(
                        fontSize: 11,
                        color: deltaColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingIndicator extends StatefulWidget {
  const _PreparingIndicator();

  @override
  State<_PreparingIndicator> createState() => _PreparingIndicatorState();
}

class _PreparingIndicatorState extends State<_PreparingIndicator> {
  Timer? _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _dotCount = _dotCount % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('準備中${'.' * _dotCount}');
  }
}

class _QuizInfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _QuizInfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
