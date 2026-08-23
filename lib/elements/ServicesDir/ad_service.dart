import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:metroapp/elements/ServicesDir/env_service.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';

class AdService {
  // Official Google AdMob Test Ad Unit IDs
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';

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

  /// Get Banner Ad Unit ID for Trip Details Screen
  static String get tripDetailsBannerAdUnitId {
    if (kIsWeb) return '';

    if (Platform.isAndroid) {
      final customId = Env.get('ADMOB_TRIP_DETAILS_BANNER_ANDROID_ID');
      if (customId.isNotEmpty) return customId;

      final generalId = Env.get('ADMOB_BANNER_ANDROID_ID');
      if (generalId.isNotEmpty) return generalId;

      return testAndroidBannerId;
    } else if (Platform.isIOS) {
      final customId = Env.get('ADMOB_TRIP_DETAILS_BANNER_IOS_ID');
      if (customId.isNotEmpty) return customId;

      final generalId = Env.get('ADMOB_BANNER_IOS_ID');
      if (generalId.isNotEmpty) return generalId;

      return testIosBannerId;
    }

    return testAndroidBannerId;
  }
}

/// Generic banner ad widget that can be used on any screen
class AppBannerAd extends StatefulWidget {
  final String adUnitId;
  final String screenName;
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;

  const AppBannerAd({
    super.key,
    required this.adUnitId,
    required this.screenName,
    this.adSize = AdSize.banner,
    this.margin,
  });

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
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

    if (widget.adUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[AdService] ${widget.screenName} banner ad loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _hasAdFailed = false;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('[AdService] ${widget.screenName} banner ad failed to load: ${error.message} (${error.code})');
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
          debugPrint('[AdService] ${widget.screenName} banner ad opened.');
          PostHogService.trackButtonClicked('${widget.screenName.toLowerCase().replaceAll(' ', '_')}_banner_ad_clicked');
        },
        onAdClosed: (Ad ad) {
          debugPrint('[AdService] ${widget.screenName} banner ad closed.');
        },
        onAdImpression: (Ad ad) {
          debugPrint('[AdService] ${widget.screenName} banner ad impression recorded.');
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
      width: double.infinity,
      margin: widget.margin ?? EdgeInsets.only(top: 6.h, bottom: 4.h),
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

/// Banner ad specifically for Stop Info screen
class StopInfoBannerAd extends StatelessWidget {
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;

  const StopInfoBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppBannerAd(
      adUnitId: AdService.stopInfoBannerAdUnitId,
      screenName: 'Stop Info',
      adSize: adSize,
      margin: margin,
    );
  }
}

/// Banner ad specifically for Trip Details screen
class TripDetailsBannerAd extends StatelessWidget {
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;

  const TripDetailsBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppBannerAd(
      adUnitId: AdService.tripDetailsBannerAdUnitId,
      screenName: 'Trip Details',
      adSize: adSize,
      margin: margin,
    );
  }
}
