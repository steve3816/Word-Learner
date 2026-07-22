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

  static const _iosRewardedTestId     = 'ca-app-pub-3940256099942544/1712485313';
  static const _androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';

  // 上架前填入 AdMob 後台的真實 Ad Unit ID
  static const _iosRewardedProdId     = '';
  static const _androidRewardedProdId = '';

  static const _quizCompletionCountKey = 'quiz_completion_count';
  static const _adFreeUntilKey = 'ad_free_until';

  /// 每次 [grantAdFree] 生效時遞增，讓已經顯示中的廣告元件能立即反應、把自己收起來。
  static final ValueNotifier<int> adFreeChanged = ValueNotifier(0);

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

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? _iosRewardedTestId : _androidRewardedTestId;
    }
    return Platform.isIOS ? _iosRewardedProdId : _androidRewardedProdId;
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

  /// 看廣告換來的無廣告期間到期時間，沒有生效中的話回傳 null。
  static Future<DateTime?> adFreeUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_adFreeUntilKey);
    if (until == null) return null;
    final untilTime = DateTime.fromMillisecondsSinceEpoch(until);
    return untilTime.isAfter(DateTime.now()) ? untilTime : null;
  }

  /// 目前是否處於看廣告換來的無廣告期間內。
  static Future<bool> isAdFree() async => (await adFreeUntil()) != null;

  /// 從現在起，往後 [AppConfig.adFreeDuration] 內不顯示廣告（每次呼叫都是重新設定，不會累加）。
  static Future<void> grantAdFree() async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(AppConfig.adFreeDuration);
    await prefs.setInt(_adFreeUntilKey, until.millisecondsSinceEpoch);
    adFreeChanged.value++;
  }
}
