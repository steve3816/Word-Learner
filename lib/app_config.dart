/// 寫死在程式碼裡的全域控制數值（不是使用者可調整的設定）。
abstract class AppConfig {
  /// 每開始幾次複習，開始時顯示一次全螢幕廣告。
  static const int quizInterstitialInterval = 20;

  /// 看一次獎勵廣告後，接下來多久不顯示任何廣告。
  static const Duration adFreeDuration = Duration(hours: 24);

  // ── 廣告單元 ID ──────────────────────────────────────────────
  // Google 官方測試 ID，debug 模式下使用，任何裝置都會拿到測試廣告。
  static const iosTestBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const androidTestBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosTestRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const androidTestRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  // 上架前填入 AdMob 後台的真實 Ad Unit ID
  static const iosProdBannerId = '';
  static const androidProdBannerId = 'ca-app-pub-3197847556942098/3357169921';
  static const iosProdInterstitialId = '';
  static const androidProdInterstitialId = 'ca-app-pub-3197847556942098/8964079190';
  static const iosProdRewardedId = '';
  static const androidProdRewardedId = 'ca-app-pub-3197847556942098/5216405871';
}
