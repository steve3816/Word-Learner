import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

class AdService {
  static const _iosTestId     = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidTestId = 'ca-app-pub-3940256099942544/6300978111';

  // 上架前填入 AdMob 後台的真實 Ad Unit ID
  static const _iosProdId     = '';
  static const _androidProdId = 'ca-app-pub-3197847556942098/3357169921';

  static const _iosInterstitialTestId     = 'ca-app-pub-3940256099942544/4411468910';
  static const _androidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';

  // 上架前填入 AdMob 後台的真實 Ad Unit ID
  static const _iosInterstitialProdId     = '';
  static const _androidInterstitialProdId = '';

  static const _quizCompletionCountKey = 'quiz_completion_count';

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? _iosTestId : _androidTestId;
    }
    return Platform.isIOS ? _iosProdId : _androidProdId;
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? _iosInterstitialTestId
          : _androidInterstitialTestId;
    }
    return Platform.isIOS
        ? _iosInterstitialProdId
        : _androidInterstitialProdId;
  }

  /// 累計一次複習完成。回傳這次是否已達到顯示全螢幕廣告的頻率（並在達標時歸零計數）。
  static Future<bool> recordQuizCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_quizCompletionCountKey) ?? 0) + 1;
    if (count >= AppConfig.quizInterstitialInterval) {
      await prefs.setInt(_quizCompletionCountKey, 0);
      return true;
    }
    await prefs.setInt(_quizCompletionCountKey, count);
    return false;
  }
}
