import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

// Appended to the user's example prompt to enforce JSON response format.
// Not user-editable — required for parsing sentence + translation.
const _exampleFormatSuffix =
    ' Also provide its Traditional Chinese translation. '
    'Return a JSON object with exactly two fields: "sentence" (the English example) '
    'and "chineseTranslation" (the Traditional Chinese translation). '
    'Return only the JSON object, no markdown, no extra text.';

class _ExampleEntry {
  final TextEditingController sentenceCtrl;
  final TextEditingController translationCtrl;
  bool loading;

  _ExampleEntry({String sentence = '', String translation = ''})
      : sentenceCtrl = TextEditingController(text: sentence),
        translationCtrl = TextEditingController(text: translation),
        loading = false;

  void dispose() {
    sentenceCtrl.dispose();
    translationCtrl.dispose();
  }
}

class AddWordScreen extends StatefulWidget {
  final Word? word;

  const AddWordScreen({super.key, this.word});

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
  final List<_ExampleEntry> _examples = [];

  AiService? _aiService;
  // Prompts loaded from settings, keyed by field name
  final Map<String, String> _prompts = {};
  bool _loadingChinese = false;
  bool _loadingExplanation = false;

  @override
  void initState() {
    super.initState();
    _englishCtrl = TextEditingController(text: widget.word?.english ?? '');
    _chineseCtrl = TextEditingController(text: widget.word?.chinese ?? '');
    _explanationCtrl =
        TextEditingController(text: widget.word?.englishExplanation ?? '');
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
    final base =
        (_prompts[field] ?? '').replaceAll('{word}', _englishCtrl.text.trim());
    return field == 'example' ? '$base$_exampleFormatSuffix' : base;
  }

  Future<void> _generateChinese() async {
    if (_englishCtrl.text.trim().isEmpty || _aiService == null) return;
    setState(() => _loadingChinese = true);
    try {
      final result = await _aiService!.complete(_buildPrompt('chinese'));
      _chineseCtrl.text = result;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI 產生失敗：$e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI 產生失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingExplanation = false);
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI 產生失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _examples[index].loading = false);
    }
  }

  void _addExample() {
    setState(() => _examples.add(_ExampleEntry()));
  }

  void _removeExample(int index) {
    setState(() {
      _examples[index].dispose();
      _examples.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
      english: _englishCtrl.text.trim(),
      chinese: _chineseCtrl.text.trim(),
      englishExplanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      examples: examples,
      createdAt: widget.word?.createdAt ?? DateTime.now(),
    );
    try {
      if (widget.word == null) {
        await _db.insertWord(word);
      } else {
        await _db.updateWord(word);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
      }
    }
  }

  Widget _aiButton({required bool loading, required VoidCallback onPressed}) {
    if (loading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton.filled(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_awesome),
      tooltip: 'AI 產生',
    );
  }

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
                  _aiButton(
                    loading: entry.loading,
                    onPressed: () => _generateExample(index),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '刪除',
                  onPressed: () => _removeExample(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: entry.sentenceCtrl,
              decoration: const InputDecoration(
                labelText: '英文例句',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: entry.translationCtrl,
              decoration: const InputDecoration(
                labelText: '例句中文翻譯',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word == null ? '新增單字' : '編輯單字'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
            TextFormField(
              controller: _englishCtrl,
              decoration: const InputDecoration(
                labelText: '英文單字 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入英文單字' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chineseCtrl,
                    decoration: const InputDecoration(
                      labelText: '中文意思 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入中文意思' : null,
                  ),
                ),
                if (_aiService != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _aiButton(
                      loading: _loadingChinese,
                      onPressed: _generateChinese,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _explanationCtrl,
                    decoration: const InputDecoration(
                      labelText: '英文解釋（選填）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),
                if (_aiService != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _aiButton(
                      loading: _loadingExplanation,
                      onPressed: _generateExplanation,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  '例句',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _save,
            child: Text(widget.word == null ? '新增' : '儲存'),
          ),
        ),
      ),
    ],
  ),
),
    );
  }
}
