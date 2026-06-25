import 'dart:io';
import 'package:flutter/foundation.dart';

class AdService {
  static const _iosTestId     = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidTestId = 'ca-app-pub-3940256099942544/6300978111';

  // 上架前填入 AdMob 後台的真實 Ad Unit ID
  static const _iosProdId     = '';
  static const _androidProdId = '';

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isIOS ? _iosTestId : _androidTestId;
    }
    return Platform.isIOS ? _iosProdId : _androidProdId;
  }
}
