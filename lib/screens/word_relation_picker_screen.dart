import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/word.dart';

class WordRelationPickerScreen extends StatefulWidget {
  final int wordBookId;
  final int? excludeWordId;
  final Set<int> alreadyRelatedIds;

  const WordRelationPickerScreen({
    super.key,
    required this.wordBookId,
    required this.excludeWordId,
    required this.alreadyRelatedIds,
  });

  @override
  State<WordRelationPickerScreen> createState() =>
      _WordRelationPickerScreenState();
}

class _WordRelationPickerScreenState extends State<WordRelationPickerScreen> {
  final _db = DbHelper();
  final _searchCtrl = TextEditingController();
  List<Word> _candidates = [];
  List<Word> _filtered = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final words = await _db.getWordsByWordBook(widget.wordBookId);
    final candidates = words
        .where((w) =>
            w.id != widget.excludeWordId &&
            !widget.alreadyRelatedIds.contains(w.id))
        .toList();
    if (mounted) {
      setState(() {
        _candidates = candidates;
        _filtered = candidates;
      });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _candidates
          : _candidates
              .where((w) =>
                  w.english.toLowerCase().contains(query) ||
                  w.chinese.contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增關聯字'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: Text('新增${_selected.isEmpty ? '' : ' (${_selected.length})'}'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋單字',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      _candidates.isEmpty ? '這本單字書沒有其他單字' : '找不到符合的單字',
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final word = _filtered[i];
                      return CheckboxListTile(
                        value: _selected.contains(word.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(word.id!);
                            } else {
                              _selected.remove(word.id!);
                            }
                          });
                        },
                        title: Text(word.english,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(word.chinese),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
