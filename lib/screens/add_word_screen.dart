import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

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
  late final TextEditingController _exampleCtrl;

  AiService? _aiService;
  bool _loadingChinese = false;
  bool _loadingExample = false;

  @override
  void initState() {
    super.initState();
    _englishCtrl = TextEditingController(text: widget.word?.english ?? '');
    _chineseCtrl = TextEditingController(text: widget.word?.chinese ?? '');
    _exampleCtrl =
        TextEditingController(text: widget.word?.exampleSentence ?? '');
    _loadAiService();
  }

  @override
  void dispose() {
    _englishCtrl.dispose();
    _chineseCtrl.dispose();
    _exampleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiService() async {
    final service = await _settings.getActiveService();
    if (mounted) setState(() => _aiService = service);
  }

  Future<void> _generateChinese() async {
    final english = _englishCtrl.text.trim();
    if (english.isEmpty || _aiService == null) return;
    setState(() => _loadingChinese = true);
    try {
      final result = await _aiService!.generateChinese(english);
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

  Future<void> _generateExample() async {
    final english = _englishCtrl.text.trim();
    if (english.isEmpty || _aiService == null) return;
    setState(() => _loadingExample = true);
    try {
      final result = await _aiService!.generateExample(english);
      _exampleCtrl.text = result;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI 產生失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _loadingExample = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final word = Word(
      id: widget.word?.id,
      english: _englishCtrl.text.trim(),
      chinese: _chineseCtrl.text.trim(),
      exampleSentence: _exampleCtrl.text.trim().isEmpty
          ? null
          : _exampleCtrl.text.trim(),
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

  Widget _aiButton({
    required bool loading,
    required VoidCallback onPressed,
  }) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word == null ? '新增單字' : '編輯單字'),
      ),
      body: Form(
        key: _formKey,
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
                    controller: _exampleCtrl,
                    decoration: const InputDecoration(
                      labelText: '例句（選填）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ),
                if (_aiService != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _aiButton(
                      loading: _loadingExample,
                      onPressed: _generateExample,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.word == null ? '新增' : '儲存'),
            ),
          ],
        ),
      ),
    );
  }
}
