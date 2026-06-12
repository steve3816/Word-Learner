import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/example_sentence.dart';
import '../models/word.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/widget_service.dart';
import '../utils/proficiency_util.dart';

const _exampleFormatSuffix =
    ' Also provide its Traditional Chinese translation. '
    'Return a JSON object with exactly two fields: "sentence" (the English example) '
    'and "chineseTranslation" (the Traditional Chinese translation). '
    'Return only the JSON object, no markdown, no extra text.';

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
  late bool _isEditing;
  Word? _currentWord;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.word == null;
    _currentWord = widget.word;
    _proficiency = widget.word?.proficiency ?? 0;
    _englishCtrl = TextEditingController(text: widget.word?.english ?? '');
    _chineseCtrl = TextEditingController(text: widget.word?.chinese ?? '');
    _explanationCtrl = TextEditingController(text: widget.word?.englishExplanation ?? '');
    _notesCtrl = TextEditingController(text: widget.word?.notes ?? '');
    if (widget.word != null) {
      for (final ex in widget.word!.examples) {
        _examples.add(_ExampleEntry(
          sentence: ex.sentence,
          translation: ex.chineseTranslation ?? '',
        ));
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
    for (final e in _examples) {
      e.dispose();
    }
    super.dispose();
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
    final base = (_prompts[field] ?? '')
        .replaceAll(SettingsService.wordPlaceholder, _englishCtrl.text.trim());
    return field == 'example' ? '$base$_exampleFormatSuffix' : base;
  }

  void _showAiError(Object e) {
    final message = e is Exception
        ? e.toString().replaceFirst('Exception: ', '')
        : e.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 回應失敗'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
        ],
      ),
    );
  }

  Future<void> _generateEnglish() async {
    if (_chineseCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingEnglish = true);
    try {
      final prompt = (_prompts['english'] ?? '').replaceAll(
          SettingsService.wordPlaceholder, _chineseCtrl.text.trim());
      final result = await _aiService!.complete(prompt);
      _englishCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingEnglish = false);
    }
  }

  Future<void> _generateChinese() async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingChinese = true);
    try {
      final result = await _aiService!.complete(_buildPrompt('chinese'));
      _chineseCtrl.text = result;
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingChinese = false);
    }
  }

  Future<void> _generateExplanation() async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingExplanation = true);
    try {
      final result = await _aiService!.complete(_buildPrompt('explanation'));
      _explanationCtrl.text = result;
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => _loadingExplanation = false);
    }
  }

  Future<void> _generateExampleSentence(int index) async {
    if (_aiService == null) return;
    final entry = _examples[index];
    if (entry.translationCtrl.text.trim().isEmpty) return;
    setState(() => entry.loadingSentence = true);
    try {
      final word = _englishCtrl.text.trim();
      final chinese = entry.translationCtrl.text.trim();
      final prompt =
          '為英文單字「$word」，根據中文意思「$chinese」，造一個自然的英文例句。只回傳英文例句本身，不要任何解釋或翻譯。';
      final result = await _aiService!.complete(prompt);
      entry.sentenceCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => entry.loadingSentence = false);
    }
  }

  Future<void> _generateExampleTranslation(int index) async {
    if (_aiService == null) return;
    final entry = _examples[index];
    if (entry.sentenceCtrl.text.trim().isEmpty) return;
    setState(() => entry.loadingTranslation = true);
    try {
      final sentence = entry.sentenceCtrl.text.trim();
      final prompt = '將以下英文例句翻譯成繁體中文：「$sentence」。只回傳中文翻譯，不要任何解釋。';
      final result = await _aiService!.complete(prompt);
      entry.translationCtrl.text = result.trim();
    } catch (e) {
      if (mounted) _showAiError(e);
    } finally {
      if (mounted) setState(() => entry.loadingTranslation = false);
    }
  }

  Future<void> _generateExample(int index) async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _examples[index].loading = true);
    try {
      final raw = await _aiService!.complete(_buildPrompt('example'));
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
      _examples.add(_ExampleEntry(
        sentence: ex.sentence,
        translation: ex.chineseTranslation ?? '',
      ));
    }
    setState(() {
      _proficiency = word.proficiency;
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('例句錯誤'),
          content: Text(
            '例句 ${invalidIndices.join('、')} 未包含英文單字「$english」，請修正後再儲存。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('確認')),
          ],
        ),
      );
      return;
    }

    final examples = _examples
        .where((e) => e.sentenceCtrl.text.trim().isNotEmpty)
        .map((e) => ExampleSentence(
              sentence: e.sentenceCtrl.text.trim(),
              chineseTranslation: e.translationCtrl.text.trim().isEmpty
                  ? null
                  : e.translationCtrl.text.trim(),
            ))
        .toList();

    final word = Word(
      id: widget.word?.id,
      english: english,
      chinese: _chineseCtrl.text.trim(),
      englishExplanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      examples: examples,
      createdAt: widget.word?.createdAt ?? DateTime.now(),
      wordBookId: widget.word?.wordBookId ?? widget.wordBookId!,
      proficiency: _proficiency,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    try {
      if (_currentWord == null) {
        await _db.insertWord(word);
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

  Widget _speakerBtn(String text) => Material(
        color: AppColors.cream2,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => TtsService.instance.speak(text),
          child: const SizedBox(
            width: 26,
            height: 26,
            child: Icon(Icons.volume_up_rounded, size: 13, color: AppColors.ink3),
          ),
        ),
      );

  Widget _aiIconBtn({required bool loading, required VoidCallback onPressed}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.auto_awesome, size: 18),
      onPressed: onPressed,
      style: IconButton.styleFrom(foregroundColor: AppColors.purpleDark),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }

  Widget _aiButton({required bool loading, required VoidCallback onPressed}) {
    if (loading) {
      return const SizedBox(
        width: 48, height: 48,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SizedBox(
      width: 48, height: 48,
      child: Tooltip(
        message: 'AI 產生',
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.purpleDark, AppColors.pinkDark],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── View mode ────────────────────────────────────────────────

  Widget _sectionCard({required Widget child}) => DecoratedBox(
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
      if (idx > start) spans.add(TextSpan(text: sentence.substring(start, idx), style: base));
      spans.add(TextSpan(
        text: sentence.substring(idx, idx + word.length),
        style: base.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
      ));
      start = idx + word.length;
    }
    if (start < sentence.length) spans.add(TextSpan(text: sentence.substring(start), style: base));
    return RichText(text: TextSpan(style: const TextStyle(color: AppColors.ink), children: spans));
  }

  Widget _buildExampleView(ExampleSentence ex) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _highlightWord(ex.sentence, _currentWord!.english)),
              const SizedBox(width: 6),
              _speakerBtn(ex.sentence),
            ],
          ),
          if (ex.chineseTranslation?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(ex.chineseTranslation!,
                style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
          ],
        ],
      );

  Widget _buildViewMode() {
    final word = _currentWord!;
    final levelLabel = proficiencyLevels
        .firstWhere((l) => l.$1 == proficiencyToLevel(_proficiency))
        .$2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        // ── Header ───────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.english,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(word.chinese,
                      style: const TextStyle(
                          fontSize: 18, color: AppColors.ink2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _speakerBtn(word.english),
          ],
        ),
        if (word.englishExplanation?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  word.englishExplanation!,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.ink3,
                      fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(width: 6),
              _speakerBtn(word.englishExplanation!),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // ── Proficiency ───────────────────────────────────────────
        _sectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text('熟練度',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.ink3,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                proficiencyIcon(_proficiency, size: 22),
                const SizedBox(width: 8),
                Text(levelLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink2,
                        fontWeight: FontWeight.w500)),
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
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  title: Text('例句（${word.examples.length}）',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  initiallyExpanded: false,
                  children: [
                    for (int i = 0; i < word.examples.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 20, thickness: 0.5),
                      _buildExampleView(word.examples[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── Notes ────────────────────────────────────────────────
        if (word.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _sectionCard(
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  title: const Text('備注',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  initiallyExpanded: false,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(word.notes!,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
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
                Text('例句 ${index + 1}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                if (_aiService != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _englishCtrl,
                    builder: (_, value, _) {
                      if (value.text.trim().isEmpty) {
                        return const SizedBox(width: 48, height: 48);
                      }
                      return _aiButton(
                        loading: entry.loading,
                        onPressed: () => _generateExample(index),
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
                        decoration: const InputDecoration(
                          labelText: '英文單字 *',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '請輸入英文單字'
                            : null,
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '請輸入中文意思'
                            : null,
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
                        decoration: const InputDecoration(labelText: '英文解釋（選填）'),
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
                              ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Text('熟練度',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: proficiencyLevels.map((level) {
                    final isSelected = _proficiency == level.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _proficiency = level.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                            SvgPicture.asset(proficiencyAsset(level.$1),
                                width: 32, height: 32),
                            const SizedBox(height: 4),
                            Text(level.$2,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('例句',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addExample,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新增例句'),
                    ),
                  ],
                ),
                for (int i = 0; i < _examples.length; i++) ...[
                  const SizedBox(height: 8),
                  _buildExampleEntry(i),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: '備注'),
                  minLines: 1,
                  maxLines: null,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GradientButton(
              onPressed: _save,
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
        title: Text(_currentWord!.english),
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
        actions: [
          TextButton(
            onPressed: _cancelEdit,
            child: const Text('取消'),
          ),
        ],
      );
    } else {
      appBar = AppBar(title: const Text('新增單字'));
    }

    return Scaffold(
      appBar: appBar,
      body: DotGridBackground(
        child: _isEditing ? _buildEditMode() : _buildViewMode(),
      ),
    );
  }
}
