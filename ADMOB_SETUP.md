# Google AdMob Setup Guide

This guide explains how to configure Google AdMob for your Aedove app.

## 📁 Configuration Files

### 1. Environment Variables (.env)

The `.env` file contains your AdMob App IDs and Ad Unit IDs. This file is **gitignored** to keep your credentials secure.

**Location:** `.env` (project root)

**Current setup:** Uses Google's test IDs by default. Switch to real IDs when your AdMob account is approved.

### 2. Constants File (constant.dart)

The `lib/constant.dart` file reads from `.env` file at runtime using `flutter_dotenv` package.

**Location:** `lib/constant.dart`

## Setup Steps

### Step 1: Get Your AdMob IDs

1. Go to [AdMob Console](https://apps.admob.com/)
2. Create or select your app
3. Copy your **AdMob App ID** (looks like: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)
4. Create ad units (Banner, Interstitial, Rewarded, Native) and copy their IDs

### Step 2: Update .env File

Edit `.env` file in the project root:

1. **Comment out the TEST IDs section** (lines under "ACTIVE - TEST IDs")
2. **Uncomment the REAL IDs section** (lines under "REAL IDs")
3. **Fill in your real AdMob IDs** from the AdMob console

Example:
```env
# ============================================
# ACTIVE - TEST IDs (Google's official test ads)
# ============================================
# ADMOB_IOS_APP_ID=ca-app-pub-3940256099942544~1458002511
# ADMOB_IOS_BANNER_ID=ca-app-pub-3940256099942544/2934735716

# ============================================
# REAL IDs (Uncomment when AdMob approved)
# ============================================
ADMOB_IOS_APP_ID=ca-app-pub-YOUR_PUBLISHER_ID~YOUR_IOS_APP_ID
ADMOB_IOS_BANNER_ID=ca-app-pub-YOUR_PUBLISHER_ID/YOUR_IOS_BANNER_ID
```

**Note:** The app automatically reads from `.env` at startup. No need to modify `constant.dart`!

### Step 3: Update Platform-Specific Configuration Files

⚠️ **Important:** These files need your **App ID** (not ad unit IDs). Update them when switching from test to production.

#### iOS (Info.plist)

**File:** `ios/Runner/Info.plist`

Find the `GADApplicationIdentifier` key and update with your iOS App ID:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-YOUR_PUBLISHER_ID~YOUR_IOS_APP_ID</string>
```

**Current value:** `ca-app-pub-3940256099942544~1458002511` (test ID)

#### Android (AndroidManifest.xml)

**File:** `android/app/src/main/AndroidManifest.xml`

Find the `com.google.android.gms.ads.APPLICATION_ID` metadata and update:

```xml
<meta-data
## 💻 Using AdMob in Your Code

### AdMob is Already Initialized!

The app automatically:
1. **Loads `.env` file** in `main.dart` using `flutter_dotenv`
2. **Initializes AdMob SDK** (currently commented out - uncomment when ready)
3. **Loads banner ads** in `HomePage`

Check `lib/main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // TODO: Uncomment when ready for AdMob
  // await MobileAds.instance.initialize();
  
  runApp(const AeDoveApp());
}
```
  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();
  
  runApp(const AeDoveApp());
}
```

### Access Ad Unit IDs

Use the platform-specific getters from `Constant`:

```dart
import 'package:aedove/constant.dart';

// Get the appropriate banner ad unit ID for the current platform
String bannerAdId = Constant.bannerAdUnitId;

// Or access directly:
String iosBannerId = Constant.admobIosBannerId;
String androidBannerId = Constant.admobAndroidBannerId;
```

### Example: Banner Ad

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:aedove/constant.dart';

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  BannerAd? _bannerAd;
  
  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }
  
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: Constant.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {}),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    )..load();
  }
  
  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_bannerAd != null)
          SizedBox(
            height: _bannerAd!.size.height.toDouble(),
            width: _bannerAd!.size.width.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        // Your other widgets
      ],
    );
  }
}
```

## Testing

The default IDs in the configuration are **Google's official test IDs**. These are safe to use during development and testing.

### Test Ad Unit IDs (Already configured)

- **iOS Banner:** `ca-app-pub-3940256099942544/2934735716`
- **Android Banner:** `ca-app-pub-3940256099942544/6300978111`
## ✅ Production Checklist

Before releasing your app:

- [ ] **AdMob account approved** - Check [AdMob Console](https://apps.admob.com/)
- [ ] **Update `.env` file** - Switch from TEST to REAL IDs
- [ ] **Update `ios/Runner/Info.plist`** - Replace test iOS App ID with real one
- [ ] **Update `android/app/src/main/AndroidManifest.xml`** - Replace test Android App ID with real one
- [ ] **Uncomment AdMob initialization** in `lib/main.dart`
- [ ] **Test ads on real devices** - Both iOS and Android
- [ ] **Verify `.env` is gitignored** - Never commit real IDs to repo
- [ ] **Create ad units in AdMob console** - Banner, Interstitial, Rewarded, Native
## 🔧 Troubleshooting

### "Account not approved yet" Error

**Error:** `LoadAdError(code: 1, domain: com.google.admob, message: Account not approved yet)`

**Solution:** Your AdMob account is still under review. Use Google's test IDs (already configured in `.env`) until approved.

### Ads not showing?

1. **Check console logs** for error messages (`flutter run` in terminal)
2. **Verify App IDs match** in `.env`, `Info.plist`, and `AndroidManifest.xml`
3. **AdMob account status** - Must be approved for production
4. **Ad unit IDs correct** - Copy exactly from AdMob console
5. **Internet permission** - Check `AndroidManifest.xml` has `INTERNET` permission
6. **Test with test IDs first** - Verify integration works before using real IDs

### iOS Specific Issues

- ✅ `GADApplicationIdentifier` must be in `Info.plist`
- ✅ `SKAdNetworkItems` array is required for iOS 14+ (already added)
- ⚠️ Test ads may not show in iOS Simulator - use real device

### Android Specific Issues

- ✅ `com.google.android.gms.ads.APPLICATION_ID` metadata must be in `AndroidManifest.xml`
- ✅ `INTERNET` permission required (already added)
- ⚠️ MinSdk must be 21+ (already configured)

### `.env` file not loading?

1. **Check file exists** - `.env` in project root
2. **Check pubspec.yaml** - `.env` listed under `assets`
3. **Run `flutter clean`** then `flutter pub get`
4. **Restart app** - Hot reload won't reload `.env` changes
- Ensure you have the `GADApplicationIdentifier` in Info.plist
- SKAdNetwork items are required for iOS 14+ attribution

### Android Specific

- Ensure you have the `com.google.android.gms.ads.APPLICATION_ID` metadata in AndroidManifest.xml
- Check that internet permission is granted

## Resources

- [Google Mobile Ads Flutter Plugin](https://pub.dev/packages/google_mobile_ads)
- [AdMob Help Center](https://support.google.com/admob)
- [AdMob Console](https://apps.admob.com/)
