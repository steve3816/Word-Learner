import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/widget_service.dart';
import '../widgets/list_proficiency_icon.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';

class WordListScreen extends StatefulWidget {
  final WordBook wordBook;

  /// 進入畫面後自動打開新增單字（目前是從桌面小工具「新增單字」觸發）。
  final bool autoAddWord;

  const WordListScreen({
    super.key,
    required this.wordBook,
    this.autoAddWord = false,
  });

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

enum _WordSort { newestFirst, oldestFirst, alpha }

class _WordListScreenState extends State<WordListScreen> {
  final _db = DbHelper();
  List<Word> _words = [];
  late WordBook _wordBook;
  _WordSort _sortOrder = _WordSort.newestFirst;

  bool _isSelecting = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _wordBook = widget.wordBook;
    _loadWords();
    if (widget.autoAddWord) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddWordScreen(
              wordBookId: widget.wordBook.id!,
              viewAfterCreate: true,
            ),
          ),
        );
        if (mounted) await _loadWords();
      });
    }
  }

  Future<void> _loadWords() async {
    final words = await _db.getWordsByWordBook(widget.wordBook.id!);
    setState(() {
      _words = _sorted(words);
    });
  }

  List<Word> _sorted(List<Word> words) {
    final list = List<Word>.from(words);
    switch (_sortOrder) {
      case _WordSort.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _WordSort.oldestFirst:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _WordSort.alpha:
        list.sort(
          (a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()),
        );
    }
    return list;
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('排序方式'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: RadioGroup<_WordSort>(
            groupValue: _sortOrder,
            onChanged: (v) => setDialogState(() => _sortOrder = v!),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<_WordSort>(
                  title: Text('字母 A–Z'),
                  value: _WordSort.alpha,
                ),
                RadioListTile<_WordSort>(
                  title: Text('新增時間：新到舊'),
                  value: _WordSort.newestFirst,
                ),
                RadioListTile<_WordSort>(
                  title: Text('新增時間：舊到新'),
                  value: _WordSort.oldestFirst,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _words = _sorted(_words));
                Navigator.pop(ctx);
              },
              child: const Text('確認'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWord(int id) async {
    await _db.deleteWord(id);
    WidgetService.syncWords();
    await _loadWords();
  }

  void _enterSelectMode(int wordId) {
    setState(() {
      _isSelecting = true;
      _selectedIds.add(wordId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int wordId) {
    setState(() {
      if (_selectedIds.contains(wordId)) {
        _selectedIds.remove(wordId);
      } else {
        _selectedIds.add(wordId);
      }
    });
  }

  Future<void> _moveSelected() async {
    final books = await _db.getAllWordBooksWithCount();
    final others = books.where((b) => b.$1.id != _wordBook.id).toList();
    if (!mounted) return;

    final target = await showDialog<WordBook>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移動到'),
        children: others.isEmpty
            ? [const SimpleDialogOption(child: Text('沒有其他單字書'))]
            : others
                  .map(
                    (b) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, b.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(b.$1.name),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );

    if (target == null || !mounted) return;
    final count = _selectedIds.length;
    await _db.moveWords(_selectedIds.toList(), target.id!);
    WidgetService.syncWords();
    _exitSelectMode();
    await _loadWords();
    if (mounted)
      showSuccessSnackBar(context, '已移動 $count 個單字到「${target.name}」');
  }

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inHours < 24) {
      return '${diff.inHours == 0 ? 1 : diff.inHours}小時內';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天內';
    } else if (diff.inDays < 14) {
      return '1禮拜';
    } else {
      return '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _exportWordBook() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('匯出此單字書'),
        content: const Text('請選擇匯出方式。'),
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
    );
    if (action == null) return;
    try {
      if (action == 'save') {
        await ExportService().saveWordBook(_wordBook);
      } else {
        await ExportService().exportWordBook(_wordBook);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, '匯出失敗：$e');
    }
  }

  Future<void> _editWordBook() async {
    final nameCtrl = TextEditingController(text: _wordBook.name);
    final descCtrl = TextEditingController(text: _wordBook.description ?? '');
    var isEditing = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('單字書設定'),
          content: isEditing
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '名稱'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: '描述'),
                      minLines: 2,
                      maxLines: 6,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _wordBook.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_wordBook.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Linkify(
                        text: _wordBook.description!,
                        style: const TextStyle(fontSize: 14),
                        linkStyle: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        onOpen: (link) => launchUrl(
                          Uri.parse(link.url),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '建立於 ${_wordBook.createdAt.year}/'
                      '${_wordBook.createdAt.month.toString().padLeft(2, '0')}/'
                      '${_wordBook.createdAt.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
          actions: isEditing
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('儲存'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('關閉'),
                  ),
                  TextButton(
                    onPressed: () => setDialogState(() => isEditing = true),
                    child: const Text('編輯'),
                  ),
                ],
        ),
      ),
    );
    if (result != true || nameCtrl.text.trim().isEmpty) return;
    final updated = _wordBook.copyWith(
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );
    await _db.updateWordBook(updated);
    if (mounted) setState(() => _wordBook = updated);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIds.length == _words.length;
    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitSelectMode();
      },
      child: Scaffold(
        appBar: _isSelecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectMode,
                ),
                title: Text('已選 ${_selectedIds.length} 個'),
                actions: [
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(_words.map((w) => w.id!));
                      }
                    }),
                    child: Text(allSelected ? '取消全選' : '全選'),
                  ),
                ],
              )
            : AppBar(
                title: Text(_wordBook.name),
                actions: [
                  if (_words.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.history_edu),
                      tooltip: '複習此單字書',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuizScreen(wordBookId: widget.wordBook.id),
                          ),
                        );
                        await _loadWords();
                      },
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'settings') {
                        _editWordBook();
                      } else if (value == 'export') {
                        _exportWordBook();
                      } else if (value == 'sort') {
                        _showSortDialog();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'settings',
                        child: ListTile(
                          leading: Icon(Icons.settings_outlined),
                          title: Text('單字書設定'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'sort',
                        child: ListTile(
                          leading: Icon(Icons.sort),
                          title: Text('排序'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.upload_file_outlined),
                          title: Text('匯出此單字書'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        body: DotGridBackground(
          child: _words.isEmpty
              ? const Center(child: Text('還沒有單字，點 + 新增吧！'))
              : SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      final selected = _selectedIds.contains(word.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.surfaceSelected
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2A2530,
                                ).withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DecoratedBox(
                            position: DecorationPosition.foreground,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                // border 是半透明色，畫在最上層時要先跟卡片底色混合成
                                // 不透明色，不然疊在滑開的紅色刪除按鈕上會被染成深紅色。
                                color: selected
                                    ? AppColors.primary
                                    : Color.alphaBlend(
                                        AppColors.border,
                                        AppColors.surface,
                                      ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Row(
                                children: [
                                  Container(width: 3, color: AppColors.primary),
                                  Expanded(
                                    child: Slidable(
                                      key: Key('word_${word.id}'),
                                      groupTag: 'word_list',
                                      endActionPane: _isSelecting
                                          ? null
                                          : ActionPane(
                                              motion: const DrawerMotion(),
                                              extentRatio: 0.2,
                                              children: [
                                                SlidableAction(
                                                  onPressed: (_) =>
                                                      _deleteWord(word.id!),
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  icon: Icons.delete,
                                                ),
                                              ],
                                            ),
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable:
                                            SettingsService.hideChinese,
                                        builder: (context, hideChinese, child) => ListTile(
                                          // 隱藏中文時沒有 subtitle，靠這個維持跟有 subtitle
                                          // 時一樣的兩行高度（72 是 ListTile 兩行的預設高度），
                                          // ListTile 在沒有 subtitle 時會把 title 垂直置中。
                                          minTileHeight: 72,
                                          // 明確指定，讓尾端內容不管顯示幾個項目，
                                          // 跟卡片右邊界永遠保持固定距離。
                                          contentPadding: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                          ),
                                          leading: _isSelecting
                                              ? Checkbox(
                                                  value: selected,
                                                  onChanged: (_) =>
                                                      _toggleSelection(
                                                        word.id!,
                                                      ),
                                                  activeColor:
                                                      AppColors.primary,
                                                )
                                              : null,
                                          title: Text(
                                            word.english,
                                            style: TextStyle(
                                              fontSize: hideChinese ? 22 : 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: hideChinese
                                              ? null
                                              : Text(word.chinese),
                                          trailing: _isSelecting
                                              ? null
                                              : ValueListenableBuilder<bool>(
                                                  valueListenable:
                                                      SettingsService
                                                          .showCreatedAt,
                                                  builder: (context, showCreatedAt, _) => ValueListenableBuilder<bool>(
                                                    valueListenable:
                                                        SettingsService
                                                            .showProficiencyIcons,
                                                    builder: (context, showProficiency, _) {
                                                      // 依序放進「有開啟」的項目，間距只插在項目「之間」，
                                                      // 這樣不管中間關掉哪個設定，最右邊到卡片邊界的距離
                                                      // 都維持固定，不會忽近忽遠。
                                                      final items = <Widget>[
                                                        if (showCreatedAt)
                                                          Text(
                                                            _formatCreatedAt(
                                                              word.createdAt,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                          ),
                                                        if (showProficiency)
                                                          SizedBox(
                                                            width: 32,
                                                            height: 32,
                                                            child: Center(
                                                              child: ListProficiencyIcon(
                                                                word.proficiency,
                                                                size: 22,
                                                              ),
                                                            ),
                                                          ),
                                                        SizedBox(
                                                          width: 32,
                                                          height: 32,
                                                          child: Center(
                                                            child: Tooltip(
                                                              message: '發音',
                                                              child: InkResponse(
                                                                radius: 16,
                                                                onTap: () =>
                                                                    TtsService
                                                                        .instance
                                                                        .speak(
                                                                          word.english,
                                                                        ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .volume_up_rounded,
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ];
                                                      return Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          for (
                                                            var i = 0;
                                                            i < items.length;
                                                            i++
                                                          ) ...[
                                                            if (i > 0)
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                            items[i],
                                                          ],
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                          onLongPress: _isSelecting
                                              ? null
                                              : () =>
                                                    _enterSelectMode(word.id!),
                                          onTap: _isSelecting
                                              ? () => _toggleSelection(word.id!)
                                              : () async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AddWordScreen(
                                                            word: word,
                                                          ),
                                                    ),
                                                  );
                                                  await _loadWords();
                                                },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        bottomNavigationBar: _isSelecting
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.drive_file_move_outline),
                    label: Text('移動到其他單字書（${_selectedIds.length}）'),
                    onPressed: _selectedIds.isEmpty ? null : _moveSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              )
            : null,
        floatingActionButton: _isSelecting
            ? null
            : GradientFAB(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddWordScreen(wordBookId: widget.wordBook.id!),
                    ),
                  );
                  await _loadWords();
                },
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
