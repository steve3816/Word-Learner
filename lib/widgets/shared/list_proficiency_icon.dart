import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../utils/proficiency_util.dart';

/// 列表類畫面用的熟練度表情圖示，依照設定頁的開關即時顯示/隱藏。
class ListProficiencyIcon extends StatelessWidget {
  final int score;
  final double size;

  const ListProficiencyIcon(this.score, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.showProficiencyIcons,
      builder: (context, show, child) =>
          show ? proficiencyIcon(score, size: size) : const SizedBox.shrink(),
    );
  }
}
