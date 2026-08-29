import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _adFreeExpiryTimer;

  @override
  void initState() {
    super.initState();
    AdService.adFreeChanged.addListener(_onAdFreeChanged);
    _load();
  }

  void _onAdFreeChanged() {
    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() => _loaded = false);
    _load();
  }

  Future<void> _load() async {
    _adFreeExpiryTimer?.cancel();
    final adFreeUntil = await AdService.adFreeUntil();
    if (adFreeUntil != null) {
      // 無廣告期間還沒到期，改成排一個到期時就自動重新載入的計時器，而不是就此放著不管。
      _adFreeExpiryTimer = Timer(adFreeUntil.difference(DateTime.now()), _load);
      return;
    }
    await AdService.ensureInitialized();
    if (!mounted) return;
    _ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.adFreeChanged.removeListener(_onAdFreeChanged);
    _adFreeExpiryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
