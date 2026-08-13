import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/example_sentence.dart';
import '../models/word.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/widget_service.dart';
import '../utils/proficiency_util.dart';
import 'word_relation_picker_screen.dart';

// 這些是程式解析回應用的格式指示，不是使用者可調整的內容，所以不會顯示在
// 長按提示詞彈窗裡，而是使用者編輯完內容後，送出前才附加回去。
// 例句＋中文翻譯的 JSON 格式指示見 [ExampleSentence.jsonFormatSuffix]（跟 quiz_screen.dart 共用）。
const _sentenceOnlyFormatSuffix = '只回傳英文例句本身，不要任何解釋或翻譯。';
const _translationOnlyFormatSuffix = '只回傳中文翻譯，不要任何解釋。';

class _ExampleEntry {
  final TextEditingController sentenceCtrl;
  final TextEditingController translationCtrl;
  bool loading;
  bool loadingSentence;
  bool loadingTranslation;

  _ExampleEntry({String sentence = '', String translation = ''})
    : sentenceCtrl = TextEditingController(text: sentence),
      translationCtrl = TextEditingController(text: translation),
      loading = false,
      loadingSentence = false,
      loadingTranslation = false;

  void dispose() {
    sentenceCtrl.dispose();
    translationCtrl.dispose();
  }
}

class AddWordScreen extends StatefulWidget {
  final Word? word;
  final int? wordBookId;

  const AddWordScreen({super.key, this.word, this.wordBookId});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _db = DbHelper();
  final _settings = SettingsService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _englishCtrl;
  late final TextEditingController _chineseCtrl;
  late final TextEditingController _explanationCtrl;
  late final TextEditingController _notesCtrl;
  final List<_ExampleEntry> _examples = [];

  AiService? _aiService;
  final Map<String, String> _prompts = {};
  bool _loadingEnglish = false;
  bool _loadingChinese = false;
  bool _loadingExplanation = false;
  late int _proficiency;
  late bool _excludeFromQuiz;
  late bool _excludeFromAiQuiz;
  late bool _isEditing;
  Word? _currentWord;

  List<Word>? _wordList;
  int _wordIndex = 0;
  List<Word> _relatedWords = [];

  final _viewScrollController = ScrollController();
  bool _showTitleWord = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.word == null;
    _currentWord = widget.word;
    _proficiency =
        widget.word?.proficiency ?? ProficiencyLevel.veryUnfamiliar.score;
    _excludeFromQuiz = widget.word?.excludeFromQuiz ?? false;
    _excludeFromAiQuiz = widget.word?.excludeFromAiQuiz ?? false;
    if (widget.word != null) {
      _loadWordList();
      _loadRelatedWords();
    }
    _viewScrollController.addListener(_onViewScroll);
    _englishCtrl = TextEditingController(text: widget.word?.english ?? '');
    _chineseCtrl = TextEditingController(text: widget.word?.chinese ?? '');
    _explanationCtrl = TextEditingController(
      text: widget.word?.englishExplanation ?? '',
    );
    _notesCtrl = TextEditingController(text: widget.word?.notes ?? '');
    if (widget.word != null) {
      for (final ex in widget.word!.examples) {
        _examples.add(
          _ExampleEntry(
            sentence: ex.sentence,
            translation: ex.chineseTranslation ?? '',
          ),
        );
      }
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _englishCtrl.dispose();
    _chineseCtrl.dispose();
    _explanationCtrl.dispose();
    _notesCtrl.dispose();
    _viewScrollController.dispose();
    for (final e in _examples) {
      e.dispose();
    }
    super.dispose();
  }

  void _onViewScroll() {
    final show = _viewScrollController.offset > 80;
    if (show != _showTitleWord) {
      setState(() => _showTitleWord = show);
    }
  }

  Future<void> _loadWordList() async {
    final words = await _db.getWordsByWordBook(_currentWord!.wordBookId);
    final idx = words.indexWhere((w) => w.id == _currentWord!.id);
    if (mounted) {
      setState(() {
        _wordList = words;
        _wordIndex = idx == -1 ? 0 : idx;
      });
    }
  }

  void _navigateTo(int index) {
    final word = _wordList![index];
    for (final e in _examples) {
      e.dispose();
    }
    if (_viewScrollController.hasClients) _viewScrollController.jumpTo(0);
    setState(() {
      _currentWord = word;
      _proficiency = word.proficiency;
      _excludeFromQuiz = word.excludeFromQuiz;
      _excludeFromAiQuiz = word.excludeFromAiQuiz;
      _wordIndex = index;
      _showTitleWord = false;
      _englishCtrl.text = word.english;
      _chineseCtrl.text = word.chinese;
      _explanationCtrl.text = word.englishExplanation ?? '';
      _notesCtrl.text = word.notes ?? '';
      _examples
        ..clear()
        ..addAll(
          word.examples.map(
            (ex) => _ExampleEntry(
              sentence: ex.sentence,
              translation: ex.chineseTranslation ?? '',
            ),
          ),
        );
    });
    _loadRelatedWords();
  }

  Future<void> _loadRelatedWords() async {
    final id = _currentWord?.id;
    if (id == null) return;
    final words = await _db.getRelatedWords(id);
    if (mounted) setState(() => _relatedWords = words);
  }

  Future<void> _openRelationPicker() async {
    final word = _currentWord;
    final wordBookId = word?.wordBookId ?? widget.wordBookId!;
    final selected = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => WordRelationPickerScreen(
          wordBookId: wordBookId,
          excludeWordId: word?.id,
          alreadyRelatedIds: _relatedWords.map((w) => w.id!).toSet(),
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    if (word?.id != null) {
      // 編輯既有單字：立刻寫入關聯。
      await _db.addWordRelations(word!.id!, selected);
      await _loadRelatedWords();
    } else {
      // 新增單字尚未存檔、沒有 id，先記在本機，存檔時才一併寫入關聯。
      final picked = await Future.wait(selected.map(_db.getWordById));
      setState(
        () => _relatedWords = [..._relatedWords, ...picked.whereType<Word>()],
      );
    }
  }

  Future<void> _removeRelation(Word relatedWord) async {
    final id = _currentWord?.id;
    if (id != null && relatedWord.id != null) {
      await _db.removeWordRelation(id, relatedWord.id!);
      await _loadRelatedWords();
    } else {
      setState(
        () => _relatedWords = _relatedWords
            .where((w) => w.id != relatedWord.id)
            .toList(),
      );
    }
  }

  Future<void> _openRelatedWord(Word relatedWord) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddWordScreen(word: relatedWord)),
    );
    await _loadRelatedWords();
  }

  Future<void> _loadSettings() async {
    final service = await _settings.getActiveService();
    final prompts = <String, String>{};
    for (final field in SettingsService.promptFields) {
      prompts[field] = await _settings.getPrompt(field);
    }
    if (mounted) {
      setState(() {
        _aiService = service;
        _prompts.addAll(prompts);
      });
    }
  }

  String _buildPrompt(String field) {
    return (_prompts[field] ?? '').replaceAll(
      SettingsService.wordPlaceholder,
      _englishCtrl.text.trim(),
    );
  }

  String _defaultEnglishPrompt() => (_prompts['english'] ?? '').replaceAll(
    SettingsService.wordPlaceholder,
    _chineseCtrl.text.trim(),
  );

  String _defaultExampleSentencePrompt(int index) =>
      '為英文單字「${_englishCtrl.text.trim()}」，'
      '根據中文意思「${_examples[index].translationCtrl.text.trim()}」，'
      '造一個自然的英文例句。';

  String _defaultExampleTranslationPrompt(int index) =>
      '將以下英文例句翻譯成繁體中文：「${_examples[index].sentenceCtrl.text.trim()}」。';

  /// 長按 AI 按鈕時彈出，讓使用者針對這一次呼叫臨時修改提示詞（不會存回設定）。
  /// 取消或沒有修改則回傳 null，維持原本的預設提示詞。
  Future<String?> _promptOverrideDialog(
    String defaultPrompt,
    String fieldLabel,
  ) async {
    final ctrl = TextEditingController(text: defaultPrompt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自訂本次提示詞'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '欄位：$fieldLabel',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder()),
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
            child: const Text('送出'),
          ),
        ],
      ),
    );
    return confirmed == true ? ctrl.text.trim() : null;
  }

  void _showAiError(Object e) {
    final message = switch (e) {
      SocketException() ||
      TimeoutException() ||
      http.ClientException() => '網路連線失敗，請檢查網路狀態後再試一次',
      Exception() => e.toString().replaceFirst('Exception: ', ''),
      _ => e.toString(),
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 回應失敗'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateEnglish({String? overridePrompt}) async {
    if (_chineseCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingEnglish = true);
    try {
      final prompt = overridePrompt ?? _defaultEnglishPrompt();
      final result = await _aiService!.complete(prompt);
      _englishCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingEnglish = false);
    }
  }

  Future<void> _generateChinese({String? overridePrompt}) async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingChinese = true);
    try {
      final prompt = overridePrompt ?? _buildPrompt('chinese');
      final result = await _aiService!.complete(prompt);
      _chineseCtrl.text = result;
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingChinese = false);
    }
  }

  Future<void> _generateExplanation({String? overridePrompt}) async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingExplanation = true);
    try {
      final prompt = overridePrompt ?? _buildPrompt('explanation');
      final result = await _aiService!.complete(prompt);
      _explanationCtrl.text = result;
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingExplanation = false);
    }
  }

  Future<void> _generateExampleSentence(
    int index, {
    String? overridePrompt,
  }) async {
    if (_aiService == null) return;
    final entry = _examples[index];
    if (entry.translationCtrl.text.trim().isEmpty) return;
    setState(() => entry.loadingSentence = true);
    try {
      final content = overridePrompt ?? _defaultExampleSentencePrompt(index);
      final prompt = '$content$_sentenceOnlyFormatSuffix';
      final result = await _aiService!.complete(prompt);
      entry.sentenceCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => entry.loadingSentence = false);
    }
  }

  Future<void> _generateExampleTranslation(
    int index, {
    String? overridePrompt,
  }) async {
    if (_aiService == null) return;
    final entry = _examples[index];
    if (entry.sentenceCtrl.text.trim().isEmpty) return;
    setState(() => entry.loadingTranslation = true);
    try {
      final content = overridePrompt ?? _defaultExampleTranslationPrompt(index);
      final prompt = '$content$_translationOnlyFormatSuffix';
      final result = await _aiService!.complete(prompt);
      entry.translationCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => entry.loadingTranslation = false);
    }
  }

  Future<void> _generateExample(int index, {String? overridePrompt}) async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _examples[index].loading = true);
    try {
      final content = overridePrompt ?? _buildPrompt('example');
      final prompt = '$content${ExampleSentence.jsonFormatSuffix}';
      final raw = await _aiService!.complete(prompt);
      final result = ExampleSentence.parseJson(raw);
      _examples[index].sentenceCtrl.text = result.sentence;
      _examples[index].translationCtrl.text = result.chineseTranslation ?? '';
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _examples[index].loading = false);
    }
  }

  void _addExample() => setState(() => _examples.add(_ExampleEntry()));

  void _removeExample(int index) {
    setState(() {
      _examples[index].dispose();
      _examples.removeAt(index);
    });
  }

  void _cancelEdit() {
    final word = _currentWord!;
    _englishCtrl.text = word.english;
    _chineseCtrl.text = word.chinese;
    _explanationCtrl.text = word.englishExplanation ?? '';
    _notesCtrl.text = word.notes ?? '';
    for (final e in _examples) {
      e.dispose();
    }
    _examples.clear();
    for (final ex in word.examples) {
      _examples.add(
        _ExampleEntry(
          sentence: ex.sentence,
          translation: ex.chineseTranslation ?? '',
        ),
      );
    }
    setState(() {
      _proficiency = word.proficiency;
      _excludeFromQuiz = word.excludeFromQuiz;
      _excludeFromAiQuiz = word.excludeFromAiQuiz;
      _isEditing = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final english = _englishCtrl.text.trim();
    final invalidIndices = <int>[];
    for (int i = 0; i < _examples.length; i++) {
      final sentence = _examples[i].sentenceCtrl.text.trim();
      if (sentence.isNotEmpty &&
          !sentence.toLowerCase().contains(english.toLowerCase())) {
        invalidIndices.add(i + 1);
      }
    }
    if (invalidIndices.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('例句未包含單字'),
          content: Text(
            '例句 ${invalidIndices.join('、')} 未包含英文單字「$english」。\n\n'
            '例句仍可儲存，但複習時將不會納入出題範圍。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('返回修改'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('仍要儲存'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final examples = _examples
        .where((e) => e.sentenceCtrl.text.trim().isNotEmpty)
        .map(
          (e) => ExampleSentence(
            sentence: e.sentenceCtrl.text.trim(),
            chineseTranslation: e.translationCtrl.text.trim().isEmpty
                ? null
                : e.translationCtrl.text.trim(),
          ),
        )
        .toList();

    final word = Word(
      id: _currentWord?.id,
      english: english,
      chinese: _chineseCtrl.text.trim(),
      englishExplanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      examples: examples,
      createdAt: _currentWord?.createdAt ?? DateTime.now(),
      wordBookId: _currentWord?.wordBookId ?? widget.wordBookId!,
      proficiency: _proficiency,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      excludeFromQuiz: _excludeFromQuiz,
      excludeFromAiQuiz: _excludeFromAiQuiz,
    );
    try {
      if (_currentWord == null) {
        final newId = await _db.insertWord(word);
        if (_relatedWords.isNotEmpty) {
          await _db.addWordRelations(
            newId,
            _relatedWords.map((w) => w.id!).toList(),
          );
        }
        WidgetService.syncWords();
        if (mounted) Navigator.pop(context);
      } else {
        await _db.updateWord(word);
        WidgetService.syncWords();
        if (mounted) {
          setState(() {
            _currentWord = word;
            _isEditing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '儲存失敗：$e');
    }
  }

  // ── Shared helpers ──────────────────────────────────────────

  Color _proficiencyBarColor(int proficiency) {
    final hue = proficiency / 100.0 * 120.0;
    return HSLColor.fromAHSL(1.0, hue, 0.75, 0.45).toColor();
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

  Widget _circleAddBtn(VoidCallback onPressed) => IconButton(
    icon: const Icon(Icons.add_circle_outline, size: 24),
    color: AppColors.primary,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
  );

  Widget _aiIconBtn({
    required bool loading,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onPressed,
        onLongPress: onLongPress,
        radius: 20,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.auto_fix_high, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }

  // ── View mode ────────────────────────────────────────────────

  Widget _sectionCard({required Widget child}) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2A2530).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _highlightWord(String sentence, String word) {
    const base = TextStyle(fontSize: 14);
    final lower = sentence.toLowerCase();
    final target = word.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lower.indexOf(target, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: sentence.substring(start, idx), style: base));
      }
      spans.add(
        TextSpan(
          text: sentence.substring(idx, idx + word.length),
          style: base.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
      start = idx + word.length;
    }
    if (start < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(start), style: base));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textPrimary),
        children: spans,
      ),
    );
  }

  Widget _buildExampleView(ExampleSentence ex) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceSelected,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _highlightWord(ex.sentence, _currentWord!.english),
              ),
              const SizedBox(width: 6),
              _speakerBtn(ex.sentence),
            ],
          ),
          if (ex.chineseTranslation?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              ex.chineseTranslation!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildViewMode() {
    final word = _currentWord!;
    final currentLevel = ProficiencyLevel.fromScore(_proficiency);

    return SelectionArea(
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _onViewScroll();
          return false;
        },
        child: ListView(
          controller: _viewScrollController,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            // ── Header ───────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        word.english,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _speakerBtn(word.english, size: 32, iconSize: 18),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  word.chinese,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (word.englishExplanation?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '英文解釋',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        word.englishExplanation!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _speakerBtn(word.englishExplanation!),
                  ],
                ),
              ),
            ],
            if (word.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '備注',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                ),
                child: Text(word.notes!, style: const TextStyle(fontSize: 14)),
              ),
            ],
            if (_relatedWords.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _sectionCard(
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      title: Text(
                        '關聯字（${_relatedWords.length}）',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      initiallyExpanded: false,
                      children: [
                        for (int i = 0; i < _relatedWords.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.borderSubtle,
                            ),
                          InkWell(
                            onTap: () => _openRelatedWord(_relatedWords[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _relatedWords[i].english,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _relatedWords[i].chinese,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Proficiency ───────────────────────────────────────────
            _sectionCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '熟練度',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(currentLevel.icon, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          currentLevel.label,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '($_proficiency%)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _proficiency / 100,
                      backgroundColor: AppColors.borderSubtle,
                      valueColor: AlwaysStoppedAnimation(
                        _proficiencyBarColor(_proficiency),
                      ),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
            ),

            // ── Examples ─────────────────────────────────────────────
            if (word.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _sectionCard(
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      title: Text(
                        '例句（${word.examples.length}）',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      initiallyExpanded: true,
                      children: [
                        for (int i = 0; i < word.examples.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _buildExampleView(word.examples[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Edit mode ────────────────────────────────────────────────

  Widget _buildExampleEntry(int index) {
    final entry = _examples[index];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '例句 ${index + 1}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Spacer(),
                if (_aiService != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _englishCtrl,
                    builder: (_, value, _) {
                      if (value.text.trim().isEmpty) {
                        return const SizedBox(width: 48, height: 48);
                      }
                      return _aiIconBtn(
                        loading: entry.loading,
                        onPressed: () => _generateExample(index),
                        onLongPress: () async {
                          final edited = await _promptOverrideDialog(
                            _buildPrompt('example'),
                            SettingsService.promptLabel('example'),
                          );
                          if (edited != null) {
                            await _generateExample(
                              index,
                              overridePrompt: edited,
                            );
                          }
                        },
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '刪除',
                  onPressed: () => _removeExample(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.sentenceCtrl,
                    decoration: const InputDecoration(
                      labelText: '英文例句',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: null,
                  ),
                ),
                if (_aiService != null) ...[
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: entry.translationCtrl,
                    builder: (_, value, _) => value.text.trim().isEmpty
                        ? const SizedBox.shrink()
                        : _aiIconBtn(
                            loading: entry.loadingSentence,
                            onPressed: () => _generateExampleSentence(index),
                            onLongPress: () async {
                              final edited = await _promptOverrideDialog(
                                _defaultExampleSentencePrompt(index),
                                '依中文造例句',
                              );
                              if (edited != null) {
                                await _generateExampleSentence(
                                  index,
                                  overridePrompt: edited,
                                );
                              }
                            },
                          ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.translationCtrl,
                    decoration: const InputDecoration(
                      labelText: '例句中文翻譯',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: null,
                  ),
                ),
                if (_aiService != null) ...[
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: entry.sentenceCtrl,
                    builder: (_, value, _) => value.text.trim().isEmpty
                        ? const SizedBox.shrink()
                        : _aiIconBtn(
                            loading: entry.loadingTranslation,
                            onPressed: () => _generateExampleTranslation(index),
                            onLongPress: () async {
                              final edited = await _promptOverrideDialog(
                                _defaultExampleTranslationPrompt(index),
                                '例句中文翻譯',
                              );
                              if (edited != null) {
                                await _generateExampleTranslation(
                                  index,
                                  overridePrompt: edited,
                                );
                              }
                            },
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _englishCtrl,
                        decoration: const InputDecoration(labelText: '英文單字 *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '請輸入英文單字' : null,
                      ),
                    ),
                    if (_aiService != null) ...[
                      const SizedBox(width: 6),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _chineseCtrl,
                        builder: (_, value, _) => value.text.trim().isEmpty
                            ? const SizedBox.shrink()
                            : _aiIconBtn(
                                loading: _loadingEnglish,
                                onPressed: _generateEnglish,
                                onLongPress: () async {
                                  final edited = await _promptOverrideDialog(
                                    _defaultEnglishPrompt(),
                                    SettingsService.promptLabel('english'),
                                  );
                                  if (edited != null) {
                                    await _generateEnglish(
                                      overridePrompt: edited,
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _chineseCtrl,
                        decoration: const InputDecoration(labelText: '中文意思 *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '請輸入中文意思' : null,
                      ),
                    ),
                    if (_aiService != null) ...[
                      const SizedBox(width: 6),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _englishCtrl,
                        builder: (_, value, _) => value.text.trim().isEmpty
                            ? const SizedBox.shrink()
                            : _aiIconBtn(
                                loading: _loadingChinese,
                                onPressed: _generateChinese,
                                onLongPress: () async {
                                  final edited = await _promptOverrideDialog(
                                    _buildPrompt('chinese'),
                                    SettingsService.promptLabel('chinese'),
                                  );
                                  if (edited != null) {
                                    await _generateChinese(
                                      overridePrompt: edited,
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _explanationCtrl,
                        decoration: const InputDecoration(labelText: '英文解釋'),
                        minLines: 2,
                        maxLines: null,
                      ),
                    ),
                    if (_aiService != null) ...[
                      const SizedBox(width: 6),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _englishCtrl,
                        builder: (_, value, _) => value.text.trim().isEmpty
                            ? const SizedBox.shrink()
                            : _aiIconBtn(
                                loading: _loadingExplanation,
                                onPressed: _generateExplanation,
                                onLongPress: () async {
                                  final edited = await _promptOverrideDialog(
                                    _buildPrompt('explanation'),
                                    SettingsService.promptLabel('explanation'),
                                  );
                                  if (edited != null) {
                                    await _generateExplanation(
                                      overridePrompt: edited,
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: '備注'),
                  minLines: 1,
                  maxLines: null,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _sectionCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '關聯字',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              _circleAddBtn(_openRelationPicker),
                            ],
                          ),
                          if (_relatedWords.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '尚無關聯字',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          else
                            for (int i = 0; i < _relatedWords.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderSubtle,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _relatedWords[i].english,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _relatedWords[i].chinese,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: AppColors.textMuted,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _removeRelation(_relatedWords[i]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _sectionCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 8, 0, 0),
                            child: Text(
                              '複習設定',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text('不納入複習出題'),
                            trailing: Checkbox(
                              value: _excludeFromQuiz,
                              onChanged: (v) =>
                                  setState(() => _excludeFromQuiz = v ?? false),
                            ),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text('不納入 AI 出題'),
                            trailing: Checkbox(
                              value: _excludeFromAiQuiz,
                              onChanged: (v) => setState(
                                () => _excludeFromAiQuiz = v ?? false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '熟練度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ProficiencyLevel.values.map((level) {
                    final isSelected = _proficiency == level.score;
                    return GestureDetector(
                      onTap: () => setState(() => _proficiency = level.score),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                            Icon(level.icon, size: 32),
                            const SizedBox(height: 4),
                            Text(
                              level.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      '例句',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    _circleAddBtn(_addExample),
                  ],
                ),
                for (int i = 0; i < _examples.length; i++) ...[
                  const SizedBox(height: 8),
                  _buildExampleEntry(i),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 32),
            child: GradientButton(
              onPressed: _save,
              height: 56,
              child: Text(widget.word == null ? '新增' : '儲存'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppBar appBar;
    if (!_isEditing) {
      appBar = AppBar(
        title: AnimatedOpacity(
          opacity: _showTitleWord ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Text(_currentWord?.english ?? ''),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '編輯',
            onPressed: () => setState(() => _isEditing = true),
          ),
        ],
      );
    } else if (widget.word != null) {
      appBar = AppBar(
        title: const Text('編輯單字'),
        actions: [TextButton(onPressed: _cancelEdit, child: const Text('取消'))],
      );
    } else {
      appBar = AppBar(title: const Text('新增單字'));
    }

    final hasList = !_isEditing && _wordList != null && _wordList!.length > 1;
    final hasPrev = hasList && _wordIndex > 0;
    final hasNext = hasList && _wordIndex < _wordList!.length - 1;

    final Widget bodyContent;
    if (_isEditing) {
      bodyContent = _buildEditMode();
    } else if (hasList) {
      bodyContent = Column(
        children: [
          Expanded(child: _buildViewMode()),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${_wordIndex + 1} / ${_wordList!.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (hasPrev)
                    Align(
                      alignment: const Alignment(-0.5, 0),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _navigateTo(_wordIndex - 1),
                      ),
                    ),
                  if (hasNext)
                    Align(
                      alignment: const Alignment(0.5, 0),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _navigateTo(_wordIndex + 1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      bodyContent = _buildViewMode();
    }

    return Scaffold(
      appBar: appBar,
      body: DotGridBackground(child: bodyContent),
    );
  }
}
