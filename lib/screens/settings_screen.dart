import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _keyControllers = <AiProvider, TextEditingController>{};
  final _obscured = <AiProvider, bool>{};
  final _promptControllers = <String, TextEditingController>{};
  AiProvider? _selectedProvider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final p in AiProvider.values) {
      _keyControllers[p] = TextEditingController();
      _obscured[p] = true;
    }
    for (final field in SettingsService.promptFields) {
      _promptControllers[field] = TextEditingController();
    }
    _loadSettings();
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settings.getSelectedProvider();
    for (final p in AiProvider.values) {
      final key = await _settings.getApiKey(p);
      _keyControllers[p]!.text = key ?? '';
    }
    for (final field in SettingsService.promptFields) {
      _promptControllers[field]!.text = await _settings.getPrompt(field);
    }
    setState(() {
      _selectedProvider = provider;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final missingWord = SettingsService.promptFields.any(
      (field) => !_promptControllers[field]!.text.contains('{word}'),
    );

    if (missingWord && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認儲存'),
          content: const Text(
            '有提示詞未包含 {word}，傳給 AI 時將不會帶入目標單字。\n確定要儲存嗎？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('確認儲存'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    for (final p in AiProvider.values) {
      await _settings.setApiKey(p, _keyControllers[p]!.text.trim());
    }
    await _settings.setSelectedProvider(_selectedProvider);
    for (final field in SettingsService.promptFields) {
      final text = _promptControllers[field]!.text.trim();
      await _settings.setPrompt(
        field,
        text.isEmpty ? await SettingsService.defaultPromptFor(field) : text,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('設定已儲存')));
      Navigator.pop(context);
    }
  }

  Future<void> _resetPrompt(String field) async {
    final def = await SettingsService.defaultPromptFor(field);
    if (mounted) setState(() => _promptControllers[field]!.text = def);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: DotGridBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ExpansionTile(
                    title: const Text(
                      '選擇 AI 提供者',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      RadioGroup<AiProvider?>(
                        groupValue: _selectedProvider,
                        onChanged: (v) => setState(() => _selectedProvider = v),
                        child: Column(
                          children: [
                            const RadioListTile<AiProvider?>(
                              title: Text('無'),
                              value: null,
                            ),
                            ...AiProvider.values.map((p) =>
                                RadioListTile<AiProvider?>(
                                  title: Text(
                                      '${p.displayName} (${p.modelName})'),
                                  value: p,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text(
                      'API Keys',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      const SizedBox(height: 8),
                      ...AiProvider.values.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: _keyControllers[p],
                            obscureText: _obscured[p]!,
                            decoration: InputDecoration(
                              labelText: '${p.displayName} API Key',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscured[p]!
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                    () => _obscured[p] = !_obscured[p]!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text(
                      'AI 提示詞設定',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          '用 {word} 代表輸入的英文單字',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...SettingsService.promptFields.map((field) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      SettingsService.promptLabel(field),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => _resetPrompt(field),
                                      child: const Text('還原預設'),
                                    ),
                                  ],
                                ),
                                  ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _promptControllers[field]!,
                                  builder: (_, value, _) {
                                    if (value.text.contains('{word}')) {
                                      return const SizedBox.shrink();
                                    }
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 14, color: Colors.red),
                                          SizedBox(width: 4),
                                          Text(
                                            '缺少目標單字標示！',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                TextField(
                                  controller: _promptControllers[field],
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GradientButton(
                onPressed: _save,
                child: const Text('儲存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
