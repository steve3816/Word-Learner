/// 寫死在程式碼裡的全域控制數值（不是使用者可調整的設定，也不是廣告單元 ID）。
abstract class AppConfig {
  /// 每完成幾次複習，離開結果頁時顯示一次全螢幕廣告。
  static const int quizInterstitialInterval = 20;

  /// 看一次獎勵廣告後，接下來多久不顯示任何廣告。
  static const Duration adFreeDuration = Duration(minutes: 1);
}
