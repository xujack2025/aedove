# Aedove

Cross‑platform, local‑network file sharing app built with Flutter.

Aedove lets you quickly send and receive files between devices on the same network — Android, iOS, macOS, Windows, Linux, and Web (Chrome). It supports selecting any files as well as picking media from the device gallery where supported.

## Key features

- Discover nearby devices on the same Wi‑Fi/LAN
- Send any files or media (images/videos) across platforms
- Save received files to platform‑appropriate locations
	- Android: Downloads (via MediaStore where possible)
	- iOS: App Documents; media optionally to Photos (with permission)
	- macOS: Downloads folder
	- Windows/Linux: App data or user directories
	- Web: Browser downloads
- Per‑device send state (send to multiple devices independently)
- App icons and product name configured for Windows, macOS, and Web

## Project structure (high‑level)

- `lib/`
	- `pages/tabs/send_tab.dart` – Select files/media and send to devices
	- `pages/tabs/receive_tab.dart` – Receive requests and manage permissions
	- `services/`
		- `device_discovery_service.dart` – LAN discovery and device registry
		- `file_transfer_service.dart` – File send/receive flows
		- `media_store_service.dart` – Facade for saving files cross‑platform
		- `permission_service.dart` – Runtime permissions
		- `notification_service.dart` – Local notifications (where supported)

## Getting started

Prerequisites:
- Flutter (stable) installed (`flutter doctor` should pass)
- Platform toolchains for the targets you care about

Run the app:

```
flutter pub get
flutter run -d <device-id>
```

Common device targets:
- Android device/emulator
- iOS simulator/device (Xcode required on macOS)
- macOS desktop: `flutter run -d macos`
- Windows desktop: `flutter run -d windows` (requires Visual Studio 2022 Desktop C++)
- Linux desktop (e.g., Ubuntu): `flutter run -d linux` (requires GTK, CMake, Ninja, Clang)
- Web (Chrome): `flutter run -d chrome`

## Platform notes

### Android
- Uses MediaStore when possible to save to Downloads.
- Requests storage permission where required by Android version.

### iOS
- Files are saved to the app’s Documents directory by default.
- Photos permission is requested only when saving media to Photos.
- Local network discovery requires the appropriate Info.plist entries (already included).

### macOS
- Files are saved to the user’s Downloads folder.
- No explicit storage permission dialog; macOS may prompt when accessing protected locations.

### Windows
- Desktop build requires Visual Studio 2022 with “Desktop development with C++” and Windows SDK.
- Icons and product metadata are configured under `windows/runner`.

### Linux (e.g., Ubuntu)
- Install build deps: `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
- Then `flutter config --enable-linux-desktop` and run.

### Web (Chrome)
- Received files are saved via standard browser download.
- Browsers cannot run a local server or broadcast on the LAN; auto‑discovery is limited.

## Permissions and configuration

This project uses `permission_handler` and declares platform permissions as needed.

- iOS (Info.plist – already present):
	- `NSPhotoLibraryUsageDescription`
	- `NSPhotoLibraryAddUsageDescription`
	- `NSLocalNetworkUsageDescription`
	- `NSLocationWhenInUseUsageDescription` (if required by discovery)
	- Bonjour services entries

- Android: storage permissions are requested at runtime where needed.

## Build and release

Android APK/AAB:
```
flutter build apk   # or: flutter build appbundle
```

iOS (on macOS):
```
flutter build ios
```

macOS:
```
flutter build macos
```

Windows:
```
flutter build windows
```

Linux:
```
flutter build linux
```

Web:
```
flutter build web
```

## Troubleshooting

- Discovery not working on Web: browsers can’t run servers or broadcast on LAN; connect directly to a device by IP or use a desktop/mobile build for full discovery.
- Windows build errors: ensure Visual Studio 2022 with Windows SDK is installed.
- iOS Photos save denied: verify Photos permissions are granted in Settings.

## Tech stack

- Flutter, Dart
- Packages: file_picker, image_picker, permission_handler, path_provider, mime, gal, connectivity_plus, network_info_plus, device_info_plus, bonsoir, socket_io_client, intl, image

## Contributing

Issues and pull requests are welcome. Please run `flutter analyze` before submitting a PR.

## License

This project is provided as‑is. Add your preferred license here (e.g., MIT, Apache‑2.0).
