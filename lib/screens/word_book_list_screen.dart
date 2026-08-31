import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/word.dart';
import '../models/word_book.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../widgets/shared/banner_ad_widget.dart';
import '../widgets/shared/list_proficiency_icon.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'word_list_screen.dart';

class WordBookListScreen extends StatefulWidget {
  const WordBookListScreen({super.key});

  @override
  State<WordBookListScreen> createState() => _WordBookListScreenState();
}

class _WordBookListScreenState extends State<WordBookListScreen>
    with TickerProviderStateMixin {
  final _db = DbHelper();
  List<(WordBook, int, int)> _wordBooks = [];
  static const _widgetChannel = MethodChannel('com.steve.haword/widget');

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showSearch = false;
  List<(Word, String)> _searchResults = [];

  int _totalWords = 0;
  int _recentWords = 0;
  int _avgProficiency = 0;

  List<(Word, String)> _recentWordsList = [];
  List<(Word, String)> _leastProficientList = [];

  late final TabController _tabController;

  bool _isSelecting = false;
  final Set<int> _selectedBookIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_isSelecting) _exitSelectMode();
        setState(() {});
      }
    });
    _loadAll();
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetUri') {
        _handleWidgetUri(Uri.tryParse(call.arguments as String? ?? ''));
      }
    });
    _checkWidgetLaunch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitSelectMode();
      },
      child: Scaffold(
        appBar: _appBar,
        body: Stack(
          children: [
            DotGridBackground(
              child: Column(
                children: [
                  _dashboard,
                  const SizedBox(height: 8),
                  _wordListsSection,
                  if (!_isSelecting) const BannerAdWidget(),
                ],
              ),
            ),
            if (_showSearch) _searchOverlay,
          ],
        ),
        bottomNavigationBar: _isSelecting
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.drive_file_move_outline),
                    label: Text('移動所有單字到...（已選 ${_selectedBookIds.length} 本）'),
                    onPressed: _selectedBookIds.isEmpty
                        ? null
                        : _moveWordsFromSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              )
            : null,
        floatingActionButton: _isSelecting || _tabController.index != 0
            ? null
            : GradientFAB(
                onPressed: _addWordBook,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  Widget _bookTile((WordBook, int, int) entry, {Key? key}) {
    final (book, count, avgProficiency) = entry;
    final selected = _selectedBookIds.contains(book.id);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSelected : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A2530).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              // border 是半透明色，畫在最上層時要先跟卡片底色混合成不透明色，
              // 不然疊在滑開的紅色刪除按鈕上會被染成深紅色而不是灰色。
              color: selected
                  ? AppColors.primary
                  : Color.alphaBlend(AppColors.border, AppColors.surface),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Slidable(
              key: Key('book_${book.id}'),
              groupTag: 'book_list',
              endActionPane: _isSelecting || book.isDefault
                  ? null
                  : ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.2,
                      children: [
                        SlidableAction(
                          onPressed: (_) => _deleteWordBook(book, count),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                        ),
                      ],
                    ),
              child: ListTile(
                leading: _isSelecting
                    ? Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleBookSelection(book.id!),
                        activeColor: AppColors.primary,
                      )
                    : const Icon(Icons.menu_book_rounded),
                title: Text(
                  book.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('$count 個單字'),
                trailing: _isSelecting
                    ? null
                    : (count > 0
                          ? ListProficiencyIcon(avgProficiency, size: 24)
                          : null),
                onLongPress: _isSelecting
                    ? null
                    : () => _enterSelectMode(book.id!),
                onTap: _isSelecting
                    ? () => _toggleBookSelection(book.id!)
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WordListScreen(wordBook: book),
                          ),
                        );
                        await _loadAll();
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 選取模式下用來拖曳排序：預設單字書固定在最上面（當作 header，不可拖曳），
  /// 其餘單字書可以自由拖曳調整順序，放開後立刻寫回資料庫。
  Widget _buildReorderableBookList() {
    final defaultEntry = _wordBooks.where((b) => b.$1.isDefault).firstOrNull;
    final others = _wordBooks.where((b) => !b.$1.isDefault).toList();
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      header: defaultEntry == null ? null : _bookTile(defaultEntry),
      // 預設的拖曳外框是直角、不透明白底，會在圓角卡片外露出一圈白邊，
      // 這裡改成透明底、跟卡片一樣的圓角，只留陰影效果。
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black26,
        child: child,
      ),
      itemCount: others.length,
      itemBuilder: (context, index) {
        final entry = others[index];
        return _bookTile(entry, key: ValueKey(entry.$1.id));
      },
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex -= 1;
        final reordered = List.of(others);
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        setState(() {
          _wordBooks = [?defaultEntry, ...reordered];
        });
        await _db.updateWordBookOrder(reordered.map((b) => b.$1.id!).toList());
      },
    );
  }

  Widget _wordTile(Word word, String bookName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: Colors.black26,
      child: ValueListenableBuilder<bool>(
        valueListenable: SettingsService.hideChinese,
        builder: (context, hideChinese, child) => ListTile(
          minTileHeight: 72,
          title: Text(
            word.english,
            style: TextStyle(
              fontSize: hideChinese ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: hideChinese ? null : Text(word.chinese),
          trailing: child,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddWordScreen(word: word)),
            );
            await _loadAll();
          },
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                bookName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            ListProficiencyIcon(word.proficiency, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _wordCrossListView(List<(Word, String)> words, String emptyText) {
    if (words.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: words.length,
      itemBuilder: (_, i) => _wordTile(words[i].$1, words[i].$2),
    );
  }

  Widget get _dashboard => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _StatItem(label: '全部單字', value: '$_totalWords'),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _StatItem(label: '本週新增', value: '$_recentWords'),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _StatItem(label: '平均熟練度', value: '$_avgProficiency%'),
        ],
      ),
    ),
  );

  Widget get _wordListsSection => Expanded(
    child: Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '單字書'),
            Tab(text: '最近'),
            Tab(text: '非常不熟'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── 單字書列表 ──
              _isSelecting
                  ? _buildReorderableBookList()
                  : SlidableAutoCloseBehavior(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _wordBooks.isEmpty ? 1 : _wordBooks.length,
                        itemBuilder: (context, index) {
                          if (_wordBooks.isEmpty) {
                            return const Center(child: Text('還沒有單字書，點 + 新增吧！'));
                          }
                          return _bookTile(_wordBooks[index]);
                        },
                      ),
                    ),
              // ── 最近新增 ──
              _wordCrossListView(_recentWordsList, '還沒有單字，點 + 新增吧！'),
              // ── 最不熟練 ──
              _wordCrossListView(_leastProficientList, '還沒有單字，點 + 新增吧！'),
            ],
          ),
        ),
      ],
    ),
  );

  AppBar get _appBar {
    if (_isSelecting) {
      final allSelected =
          _wordBooks.isNotEmpty &&
          _wordBooks.every((b) => _selectedBookIds.contains(b.$1.id));
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        title: Text('已選 ${_selectedBookIds.length} 本'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selectedBookIds.clear();
              } else {
                _selectedBookIds.addAll(_wordBooks.map((b) => b.$1.id!));
              }
            }),
            child: Text(allSelected ? '取消全選' : '全選'),
          ),
        ],
      );
    }
    final totalWordCount = _wordBooks.fold(0, (sum, e) => sum + e.$2);
    return AppBar(
      actions: [
        _searchButton,
        if (totalWordCount >= 3) _reviewButton,
        _settingsButton,
      ],
    );
  }

  Widget get _searchButton => IconButton(
    icon: const Icon(Icons.search),
    onPressed: () {
      setState(() => _showSearch = true);
      _searchFocus.requestFocus();
    },
  );

  Widget get _reviewButton => IconButton(
    icon: const Icon(Icons.history_edu),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuizScreen()),
      );
      if (mounted) await _loadAll();
    },
  );

  Widget get _settingsButton => IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      _loadAll();
    },
  );

  Widget get _searchOverlay => Material(
    color: Colors.white,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '搜尋單字...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _closeSearch,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: _searchCtrl.text.isEmpty
              ? const Center(
                  child: Text('請輸入關鍵字', style: TextStyle(color: Colors.grey)),
                )
              : _searchResults.isEmpty
              ? const Center(
                  child: Text('沒有符合的單字', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final (word, bookName) = _searchResults[index];
                    return ListTile(
                      leading: ListProficiencyIcon(word.proficiency, size: 28),
                      title: Text(word.english),
                      subtitle: Text(word.chinese),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          bookName,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      onTap: () async {
                        _closeSearch();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddWordScreen(word: word),
                          ),
                        );
                        await _loadAll();
                      },
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _db.getAllWordBooksWithCount(),
      _db.getWordStats(),
      _db.getRecentWordsWithBook(),
      _db.getLeastProficientWordsWithBook(),
    ]);
    if (!mounted) return;
    setState(() {
      _wordBooks = results[0] as List<(WordBook, int, int)>;
      final stats =
          results[1] as ({int total, int recentCount, int avgProficiency});
      _totalWords = stats.total;
      _recentWords = stats.recentCount;
      _avgProficiency = stats.avgProficiency;
      _recentWordsList = results[2] as List<(Word, String)>;
      _leastProficientList = results[3] as List<(Word, String)>;
    });
  }

  Future<void> _checkWidgetLaunch() async {
    final uri = await _widgetChannel.invokeMethod<String>('getInitialUri');
    if (uri != null) _handleWidgetUri(Uri.tryParse(uri));
  }

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null) return;
    if (uri.host == 'addword') {
      final id = int.tryParse(uri.queryParameters['wordBookId'] ?? '');
      if (id == null || id == -1) return;
      final wordBook = await _db.getWordBook(id);
      if (wordBook == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                WordListScreen(wordBook: wordBook, autoAddWord: true),
          ),
          (route) => route.isFirst,
        );
        if (mounted) await _loadAll();
      });
    } else if (uri.host == 'word') {
      final wordId = int.tryParse(uri.queryParameters['wordId'] ?? '');
      if (wordId == null) return;
      final word = await _db.getWordById(wordId);
      if (word == null || !mounted) return;
      final wordBook = await _db.getWordBook(word.wordBookId);
      if (wordBook == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => WordListScreen(wordBook: wordBook)),
          (route) => route.isFirst,
        );
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AddWordScreen(word: word)));
      });
    }
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _showSearch = false;
      _searchResults = [];
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _db.searchWords(query.trim());
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _addWordBook() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增單字書'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '名稱 *'),
              onSubmitted: (_) {},
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(hintText: '描述'),
              minLines: 2,
              maxLines: 6,
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
            child: const Text('新增'),
          ),
        ],
      ),
    );
    if (result != true || nameCtrl.text.trim().isEmpty) return;
    await _db.insertWordBook(
      WordBook(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await _loadAll();
  }

  Future<void> _deleteWordBook(WordBook book, int wordCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除單字書'),
        content: Text(
          wordCount > 0
              ? '刪除「${book.name}」將同時刪除其中 $wordCount 個單字，確定嗎？'
              : '確定刪除「${book.name}」嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteWordBook(book.id!);
    await WidgetService.syncWords();
    await _loadAll();
  }

  void _enterSelectMode(int bookId) {
    setState(() {
      _isSelecting = true;
      _selectedBookIds.add(bookId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedBookIds.clear();
    });
  }

  void _toggleBookSelection(int bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  Future<void> _moveWordsFromSelected() async {
    final books = await _db.getAllWordBooksWithCount();
    // Target can be any book not in the selected set
    final targets = books
        .where((b) => !_selectedBookIds.contains(b.$1.id))
        .toList();
    if (!mounted) return;

    final target = await showDialog<WordBook>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移動到'),
        children: targets.isEmpty
            ? [const SimpleDialogOption(child: Text('沒有其他單字書'))]
            : targets
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
    final count = _selectedBookIds.length;
    await _db.moveWordsByBooks(_selectedBookIds.toList(), target.id!);
    WidgetService.syncWords();
    _exitSelectMode();
    await _loadAll();
    if (mounted) {
      showSuccessSnackBar(context, '已將 $count 本單字書的單字移動到「${target.name}」');
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
