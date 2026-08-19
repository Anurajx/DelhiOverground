import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:metroapp/elements/ServicesDir/env_service.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';
import 'package:metroapp/main.dart';

class AdService {
  // Official Google AdMob Test Ad Unit IDs
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  static const String testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initialize Google Mobile Ads SDK
  static Future<InitializationStatus?> initialize() async {
    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads initialized successfully.');
      return status;
    } catch (e, stack) {
      debugPrint('[AdService] Failed to initialize Google Mobile Ads: $e');
      PostHogService.trackAppException(e, stack);
      return null;
    }
  }

  /// Get Banner Ad Unit ID for Stop Info Screen
  /// Reads custom ID from .env or falls back to Google's standard test Ad Unit IDs
  static String get stopInfoBannerAdUnitId {
    if (kIsWeb) return '';

    if (Platform.isAndroid) {
      final customId = Env.get('ADMOB_STOP_INFO_BANNER_ANDROID_ID');
      if (customId.isNotEmpty) return customId;

      final generalId = Env.get('ADMOB_BANNER_ANDROID_ID');
      if (generalId.isNotEmpty) return generalId;

      return testAndroidBannerId;
    } else if (Platform.isIOS) {
      final customId = Env.get('ADMOB_STOP_INFO_BANNER_IOS_ID');
      if (customId.isNotEmpty) return customId;

      final generalId = Env.get('ADMOB_BANNER_IOS_ID');
      if (generalId.isNotEmpty) return generalId;

      return testIosBannerId;
    }

    return testAndroidBannerId;
  }
}

/// A dedicated banner ad widget styled for the Stop Info screen
class StopInfoBannerAd extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;
  final bool showAdLabel;

  const StopInfoBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
    this.showAdLabel = false,
  });

  @override
  State<StopInfoBannerAd> createState() => _StopInfoBannerAdState();
}

class _StopInfoBannerAdState extends State<StopInfoBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasAdFailed = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb) return;

    final adUnitId = AdService.stopInfoBannerAdUnitId;
    if (adUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[AdService] Stop Info banner ad loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _hasAdFailed = false;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('[AdService] Stop Info banner ad failed to load: ${error.message} (${error.code})');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
              _hasAdFailed = true;
            });
          }
        },
        onAdOpened: (Ad ad) {
          debugPrint('[AdService] Stop Info banner ad opened.');
          PostHogService.trackButtonClicked('stop_info_ad_clicked');
        },
        onAdClosed: (Ad ad) {
          debugPrint('[AdService] Stop Info banner ad closed.');
        },
        onAdImpression: (Ad ad) {
          debugPrint('[AdService] Stop Info banner ad impression recorded.');
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null || _hasAdFailed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? EdgeInsets.only(top: 8.h, bottom: 6.h),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showAdLabel)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(
                "ADVERTISEMENT",
                style: TextStyle(
                  color: AppColors.tertiaryText,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      ),
    );
  }
}
