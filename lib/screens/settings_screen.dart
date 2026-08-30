import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../app_config.dart';
import '../app_theme.dart';
import '../services/ad_service.dart';
import '../services/ai_service.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../utils/proficiency_util.dart';

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
  final _promptFocusNodes = <String, FocusNode>{};
  String? _focusedPromptField;
  AiProvider? _selectedProvider;
  int _quizMaxProficiency = ProficiencyLevel.proficient.score;
  bool _aiQuizEnabled = false;
  bool _loading = true;

  RewardedAd? _rewardedAd;

  /// 是否已經設定好可用的 AI（選了提供者、且該提供者的 API Key 有填），
  /// 「AI 出題」開關要靠這個才能打開。
  bool get _aiFeatureEnabled =>
      _selectedProvider != null &&
      (_keyControllers[_selectedProvider]?.text.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    for (final p in AiProvider.values) {
      _keyControllers[p] = TextEditingController();
      _obscured[p] = true;
    }
    for (final field in SettingsService.promptFields) {
      _promptControllers[field] = TextEditingController();
      final node = FocusNode();
      node.addListener(() {
        setState(() => _focusedPromptField = node.hasFocus ? field : null);
      });
      _promptFocusNodes[field] = node;
    }
    _loadSettings();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    for (final n in _promptFocusNodes.values) {
      n.dispose();
    }
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('設定'), actions: [_infoButton]),
      body: DotGridBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _aiProviderCard,
            _aiApiKeyCard,
            _aiPromptCard,
            _reviewCard,
            _displayCard,
            _dataManagementCard,
            _watchAdCard,
          ],
        ),
      ),
      bottomNavigationBar: _saveButton,
    );
  }

  Future<void> _loadRewardedAd() async {
    await AdService.ensureInitialized();
    RewardedAd.load(
      adUnitId: AdService.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  void _watchRewardedAd() {
    final ad = _rewardedAd;
    if (ad == null) return;
    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        await AdService.grantAdFree();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('謝謝支持！接下來的廣告已為你移除')));
      },
    );
  }

  Widget _settingsCard(Widget expansionTile) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 3,
    shadowColor: Colors.black26,
    child: Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: expansionTile,
    ),
  );

  // 右上使用說明按鈕
  Widget get _infoButton => IconButton(
    icon: const Icon(Icons.info_outline),
    onPressed: () => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使用說明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(
              icon: Icons.auto_fix_high,
              text: 'AI填寫功能需填入對應服務的 API Key 才會啟用，未填入時相關按鈕不會出現。',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.key_outlined,
              text:
                  'API Key 是 AI 服務商核發給您的個人授權碼，用來驗證身分與計算用量，通常需先至該服務官方網站申請及付費才能取得。',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.storage_outlined,
              text: '單字資料儲存於本機裝置，刪除 App 時將一併刪除，建議定期使用「匯出」功能備份。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('了解'),
          ),
        ],
      ),
    ),
  );

  // AI 提供者card
  Widget get _aiProviderCard => _settingsCard(
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text(
                  'AI 提供者',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        ...AiProvider.values.map(
                          (p) => RadioListTile<AiProvider?>(
                            title: Text('${p.displayName} (${p.modelName})'),
                            value: p,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

  Widget get _aiApiKeyCard => _settingsCard(
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text(
                  'API 金鑰',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
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
                            onPressed: () =>
                                setState(() => _obscured[p] = !_obscured[p]!),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '*金鑰僅儲存於本機裝置，只在呼叫 API 時使用',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
              ),
            );           
  
  Widget get _aiPromptCard => _settingsCard(
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.edit_note),
              title: const Text(
                'AI 提示詞',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '用 {word} 代表輸入的英文單字',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...SettingsService.promptFields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              SettingsService.promptLabel(field),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: _focusedPromptField == field
                                  ? TextButton(
                                      key: const ValueKey('insert'),
                                      onPressed: () =>
                                          _insertWordPlaceholder(field),
                                      child: const Text('插入 {word}'),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('hidden'),
                                    ),
                            ),
                            TextButton(
                              onPressed: () => _resetPrompt(field),
                              child: const Text('還原預設'),
                            ),
                          ],
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _promptControllers[field]!,
                          builder: (_, value, _) {
                            if (value.text.contains(
                              SettingsService.wordPlaceholder,
                            )) {
                              return const SizedBox.shrink();
                            }
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '缺少目標單字標示！',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        TextField(
                          controller: _promptControllers[field],
                          focusNode: _promptFocusNodes[field],
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

  Widget get _reviewCard => _settingsCard(
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.school_outlined),
              title: const Text(
                '複習設定',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '出題熟練度範圍',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                RadioGroup<int>(
                  groupValue: _quizMaxProficiency,
                  onChanged: (v) => setState(() => _quizMaxProficiency = v!),
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        title: const Text('全部'),
                        value: ProficiencyLevel.proficient.score,
                      ),
                      RadioListTile<int>(
                        title: const Text('普通以下'),
                        value: ProficiencyLevel.proficient.score - 1,
                      ),
                      RadioListTile<int>(
                        title: const Text('有點不熟以下'),
                        value: ProficiencyLevel.neutral.score,
                      ),
                      RadioListTile<int>(
                        title: const Text('非常不熟'),
                        value: ProficiencyLevel.unfamiliar.score,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                const Text(
                  'AI 出題',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AI 出題'),
                  value: _aiQuizEnabled && _aiFeatureEnabled,
                  onChanged: _aiFeatureEnabled
                      ? (v) => setState(() => _aiQuizEnabled = v)
                      : null,
                ),
                const Text(
                  '開啟後，複習時題目有機率為 AI 生成例句填空題',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          );

  Widget get _displayCard => _settingsCard(
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.tune),
              title: const Text(
                '顯示設定',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.showProficiencyIcons,
                  builder: (context, show, child) => SwitchListTile(
                    title: const Text('列表顯示單字熟練度'),
                    value: show,
                    onChanged: (v) => _settings.setShowProficiencyIcons(v),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.showCreatedAt,
                  builder: (context, show, child) => SwitchListTile(
                    title: const Text('列表顯示單字創建時間'),
                    value: show,
                    onChanged: (v) => _settings.setShowCreatedAt(v),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.hideChinese,
                  builder: (context, hide, child) => SwitchListTile(
                    title: const Text('隱藏單字中文翻譯'),
                    value: hide,
                    onChanged: (v) => _settings.setHideChinese(v),
                  ),
                ),
              ],
            ),
          );

  Widget get _dataManagementCard => _settingsCard(
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.folder_open),
              title: const Text(
                '資料管理',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('匯出全部單字書'),
                  onTap: _exportAll,
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('匯入單字書'),
                  onTap: _import,
                ),
              ],
            ),
          );

  Widget get _watchAdCard => Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '支持開發者',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '看一支廣告支持我們，接下來 ${AppConfig.adFreeDuration.inHours} 小時內都不會顯示廣告',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _watchRewardedAd,
                    child: const Text('看廣告'),
                  ),
                ],
              ),
            ),
          );
   
  Widget get _saveButton => Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
            child: GradientButton(
              onPressed: _save,
              height: 56,
              child: const Text('儲存'),
            ),
          ),
        ),
      ); 

  Future<void> _loadSettings() async {
    final provider = await _settings.getSelectedProvider();
    for (final p in AiProvider.values) {
      final key = await _settings.getApiKey(p);
      _keyControllers[p]!.text = key ?? '';
    }
    for (final field in SettingsService.promptFields) {
      _promptControllers[field]!.text = await _settings.getPrompt(field);
    }
    final quizMax = await _settings.getQuizMaxProficiency();
    final aiQuizEnabled = await _settings.getAiQuizEnabled();
    setState(() {
      _selectedProvider = provider;
      _quizMaxProficiency = quizMax;
      _aiQuizEnabled = aiQuizEnabled;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final missingWord = SettingsService.promptFields.any(
      (field) => !_promptControllers[field]!.text.contains(
        SettingsService.wordPlaceholder,
      ),
    );

    if (missingWord && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認儲存'),
          content: const Text('有提示詞未包含 {word}，傳給 AI 時將不會帶入目標單字。\n確定要儲存嗎？'),
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
    await _settings.setQuizMaxProficiency(_quizMaxProficiency);
    await _settings.setAiQuizEnabled(_aiQuizEnabled && _aiFeatureEnabled);
    for (final field in SettingsService.promptFields) {
      final text = _promptControllers[field]!.text.trim();
      await _settings.setPrompt(
        field,
        text.isEmpty ? await SettingsService.defaultPromptFor(field) : text,
      );
    }
    if (mounted) {
      showSuccessSnackBar(context, '設定已儲存');
      Navigator.pop(context);
    }
  }

  Future<void> _resetPrompt(String field) async {
    final def = await SettingsService.defaultPromptFor(field);
    if (mounted) setState(() => _promptControllers[field]!.text = def);
  }

  Future<void> _exportAll() async {
    bool includePrompts = false;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('匯出全部單字書'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('將所有單字書匯出為 JSON 檔案。'),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('包含提示詞設定'),
                value: includePrompts,
                onChanged: (v) => setState(() => includePrompts = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('儲存到本機'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text('分享'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'save') {
        await ExportService().saveAll(includePrompts: includePrompts);
      } else {
        await ExportService().exportAll(includePrompts: includePrompts);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '匯出失敗：$e');
    }
  }

  Future<void> _import() async {
    final service = ExportService();
    ImportPreview? preview;
    try {
      preview = await service.pickAndPreview();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '讀取檔案失敗：$e');
      return;
    }
    if (preview == null || !mounted) return;

    bool importPrompts = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('確認匯入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('檔案：${preview!.fileName}'),
              const SizedBox(height: 4),
              Text('單字書：${preview.wordBookCount} 本　單字：${preview.wordCount} 個'),
              const SizedBox(height: 8),
              ...preview.bookNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text('• $name', style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (preview.hasPrompts) ...[
                const Divider(height: 20),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同時匯入提示詞設定'),
                  subtitle: const Text(
                    '將覆蓋現有提示詞',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: importPrompts,
                  onChanged: (v) => setState(() => importPrompts = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('匯入'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await service.importData(preview, importPrompts: importPrompts);
      await WidgetService.syncWords();
      if (mounted) showSuccessSnackBar(context, '匯入成功');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '匯入失敗：$e');
    }
  }

  void _insertWordPlaceholder(String field) {
    final controller = _promptControllers[field]!;
    final text = controller.text;
    final pos = controller.selection.baseOffset;
    final insert = pos < 0 ? text.length : pos;
    controller.value = controller.value.copyWith(
      text:
          text.substring(0, insert) +
          SettingsService.wordPlaceholder +
          text.substring(insert),
      selection: TextSelection.collapsed(
        offset: insert + SettingsService.wordPlaceholder.length,
      ),
    );
  }

  
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

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
