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
  final _controllers = <AiProvider, TextEditingController>{};
  final _obscured = <AiProvider, bool>{};
  AiProvider? _selectedProvider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final p in AiProvider.values) {
      _controllers[p] = TextEditingController();
      _obscured[p] = true;
    }
    _loadSettings();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settings.getSelectedProvider();
    for (final p in AiProvider.values) {
      final key = await _settings.getApiKey(p);
      _controllers[p]!.text = key ?? '';
    }
    setState(() {
      _selectedProvider = provider;
      _loading = false;
    });
  }

  Future<void> _save() async {
    for (final p in AiProvider.values) {
      await _settings.setApiKey(p, _controllers[p]!.text.trim());
    }
    if (_selectedProvider != null) {
      await _settings.setSelectedProvider(_selectedProvider!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('設定已儲存')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '選擇 AI 提供者',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          RadioGroup<AiProvider>(
            groupValue: _selectedProvider,
            onChanged: (v) => setState(() => _selectedProvider = v),
            child: Column(
              children: AiProvider.values
                  .map((p) => RadioListTile<AiProvider>(
                        title: Text(p.displayName),
                        value: p,
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 32),
          const Text(
            'API Keys',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...AiProvider.values.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _controllers[p],
                obscureText: _obscured[p]!,
                decoration: InputDecoration(
                  labelText: '${p.displayName} API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured[p]! ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscured[p] = !_obscured[p]!),
                  ),
                ),
              ),
            ),
          ),
          ElevatedButton(onPressed: _save, child: const Text('儲存')),
        ],
      ),
    );
  }
}
