import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

class AdService {
  static const _quizStartCountKey = 'quiz_completion_count';
  static const _adFreeUntilKey = 'ad_free_until';

  static Future<InitializationStatus>? _initialization;

  /// 第一次呼叫時才真正觸發 SDK 初始化，之後重複呼叫都拿到同一個 Future。
  /// 廣告元件載入前都要先 await 這個，避免在 SDK 準備好之前送出廣告請求而失敗。
  static Future<InitializationStatus> ensureInitialized() {
    return _initialization ??= MobileAds.instance.initialize();
  }

  /// 每次 [grantAdFree] 生效時遞增，讓已經顯示中的廣告元件能立即反應、把自己收起來。
  static final ValueNotifier<int> adFreeChanged = ValueNotifier(0);

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? AppConfig.iosTestBannerId
          : AppConfig.androidTestBannerId;
    }
    return Platform.isIOS
        ? AppConfig.iosProdBannerId
        : AppConfig.androidProdBannerId;
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? AppConfig.iosTestInterstitialId
          : AppConfig.androidTestInterstitialId;
    }
    return Platform.isIOS
        ? AppConfig.iosProdInterstitialId
        : AppConfig.androidProdInterstitialId;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? AppConfig.iosTestRewardedId
          : AppConfig.androidTestRewardedId;
    }
    return Platform.isIOS
        ? AppConfig.iosProdRewardedId
        : AppConfig.androidProdRewardedId;
  }

  /// 累計一次複習開始。回傳這次是否已達到顯示全螢幕廣告的頻率（並在達標時歸零計數）。
  static Future<bool> recordQuizStart() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_quizStartCountKey) ?? 0) + 1;
    if (count >= AppConfig.quizInterstitialInterval) {
      await prefs.setInt(_quizStartCountKey, 0);
      return true;
    }
    await prefs.setInt(_quizStartCountKey, count);
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
