import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../app_theme.dart';
import '../../models/word.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../shared/list_proficiency_icon.dart';

/// 單字列表（「我的單字書」）裡的一列單字卡片：左滑刪除、長按進入選取模式、
/// 點擊進入單字頁。所有「做什麼」都透過 callback 交給外面的畫面決定，
/// 這個元件只負責長相跟手勢。
class WordListTile extends StatelessWidget {
  final Word word;
  final bool selected;
  final bool isSelecting;
  final VoidCallback onToggleSelect;
  final VoidCallback onEnterSelectMode;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const WordListTile({
    super.key,
    required this.word,
    required this.selected,
    required this.isSelecting,
    required this.onToggleSelect,
    required this.onEnterSelectMode,
    required this.onDelete,
    required this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSelected : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              // border 是半透明色，畫在最上層時要先跟卡片底色混合成
              // 不透明色，不然疊在滑開的紅色刪除按鈕上會被染成深紅色。
              color: selected
                  ? AppColors.primary
                  : Color.alphaBlend(AppColors.border, AppColors.surface),
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
                    endActionPane: isSelecting
                        ? null
                        : ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.2,
                            children: [
                              SlidableAction(
                                onPressed: (_) => onDelete(),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                              ),
                            ],
                          ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: SettingsService.hideChinese,
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
                        leading: isSelecting
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => onToggleSelect(),
                                activeColor: AppColors.primary,
                              )
                            : null,
                        title: Text(
                          word.english,
                          style: TextStyle(
                            fontSize: hideChinese ? 22 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: hideChinese ? null : Text(word.chinese),
                        trailing: isSelecting
                            ? null
                            : ValueListenableBuilder<bool>(
                                valueListenable: SettingsService.showCreatedAt,
                                builder: (context, showCreatedAt, _) =>
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          SettingsService.showProficiencyIcons,
                                      builder: (context, showProficiency, _) {
                                        // 依序放進「有開啟」的項目，間距只插在項目「之間」，
                                        // 這樣不管中間關掉哪個設定，最右邊到卡片邊界的距離
                                        // 都維持固定，不會忽近忽遠。
                                        final items = <Widget>[
                                          if (showCreatedAt)
                                            Text(
                                              _formatCreatedAt(word.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
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
                                              child: InkResponse(
                                                radius: 16,
                                                onTap: () => TtsService.instance
                                                    .speak(word.english),
                                                child: const Icon(
                                                  Icons.volume_up_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ];
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < items.length;
                                              i++
                                            ) ...[
                                              if (i > 0)
                                                const SizedBox(width: 4),
                                              items[i],
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                              ),
                        onLongPress: isSelecting
                            ? null
                            : () => onEnterSelectMode(),
                        onTap: isSelecting
                            ? () => onToggleSelect()
                            : () => onTap(),
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
  }
}
