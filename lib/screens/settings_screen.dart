import 'package:flutter/material.dart';
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ExpansionTile(
                  title: const Text(
                    '選擇 AI 提供者',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscured[p]!
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() => _obscured[p] = !_obscured[p]!),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              const SizedBox(height: 4),
                              TextField(
                                controller: _promptControllers[field],
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('儲存'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
