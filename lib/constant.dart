import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constant {
  static final String AD_URL =
      "https://aedove.com/A09-Ads/Attachments/hp-advertise-today.png";

  static final String AD_API =
      "https://aedove.com/A09-Ads/ADS-API/mobile-ads-api.php";

  // Google AdMob Configuration
  // Reads from .env file for security - never commit real IDs to git!

  // AdMob App IDs - loaded from .env
  static String get admobIosAppId => dotenv.get(
    'ADMOB_IOS_APP_ID',
    fallback: 'ca-app-pub-3940256099942544~1458002511',
  );
  static String get admobAndroidAppId => dotenv.get(
    'ADMOB_ANDROID_APP_ID',
    fallback: 'ca-app-pub-3940256099942544~3347511713',
  );

  // Banner Ad Unit IDs
  static String get admobIosBannerId => dotenv.get(
    'ADMOB_IOS_BANNER_ID',
    fallback: 'ca-app-pub-3940256099942544/2934735716',
  );
  static String get admobAndroidBannerId => dotenv.get(
    'ADMOB_ANDROID_BANNER_ID',
    fallback: 'ca-app-pub-3940256099942544/6300978111',
  );

  // Interstitial Ad Unit IDs
  static String get admobIosInterstitialId => dotenv.get(
    'ADMOB_IOS_INTERSTITIAL_ID',
    fallback: 'ca-app-pub-3940256099942544/4411468910',
  );
  static String get admobAndroidInterstitialId => dotenv.get(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    fallback: 'ca-app-pub-3940256099942544/1033173712',
  );

  // Rewarded Ad Unit IDs
  static String get admobIosRewardedId => dotenv.get(
    'ADMOB_IOS_REWARDED_ID',
    fallback: 'ca-app-pub-3940256099942544/1712485313',
  );
  static String get admobAndroidRewardedId => dotenv.get(
    'ADMOB_ANDROID_REWARDED_ID',
    fallback: 'ca-app-pub-3940256099942544/5224354917',
  );

  // Native Ad Unit IDs
  static String get admobIosNativeId => dotenv.get(
    'ADMOB_IOS_NATIVE_ID',
    fallback: 'ca-app-pub-3940256099942544/3986624511',
  );
  static String get admobAndroidNativeId => dotenv.get(
    'ADMOB_ANDROID_NATIVE_ID',
    fallback: 'ca-app-pub-3940256099942544/2247696110',
  );

  // Platform-specific getters for easy access
  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      return admobIosBannerId;
    } else if (Platform.isAndroid) {
      return admobAndroidBannerId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return admobIosInterstitialId;
    } else if (Platform.isAndroid) {
      return admobAndroidInterstitialId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (Platform.isIOS) {
      return admobIosRewardedId;
    } else if (Platform.isAndroid) {
      return admobAndroidRewardedId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get nativeAdUnitId {
    if (Platform.isIOS) {
      return admobIosNativeId;
    } else if (Platform.isAndroid) {
      return admobAndroidNativeId;
    }
    throw UnsupportedError('Unsupported platform');
  }
}
