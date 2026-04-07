# Aedove

Aedove is a Flutter-based local network file sharing app built with Clean Architecture, BLoC, and dependency injection.

It allows Android, iOS, macOS, Windows to discover peers on the same LAN and transfer files directly over HTTP.

## What it does

- Discover nearby devices on the same Wi-Fi/LAN
- Send files and media to selected devices
- Receive transfer requests with per-file accept/deny
- Track transfer progress and recently saved files
- Save media/files using platform-appropriate storage behavior

## Current architecture

This project follows a layered architecture:

- Presentation layer (`lib/presentation`)
	- Pages, feature widgets, and BLoC state management
	- BLoCs: `app_init`, `ads`, `discovery`, `transfer`, `settings`
- Domain layer (`lib/domain`)
	- Entities, repository interfaces, use cases
	- Pure business rules without Flutter/framework coupling
- Data layer (`lib/data`)
	- Repository implementations, data sources, and models
	- Bridges domain APIs to low-level services
- Service/infrastructure layer (`lib/services`)
	- Device discovery, transfer server/client, media save, notification, permission
	- Used by data sources as implementation details
- DI bootstrap (`lib/di/service_locator.dart`)
	- `get_it` registrations for data/domain/presentation wiring

### High-level flow

1. App starts with `AppInitBloc` and initializes background/network services.
2. `DiscoveryBloc` streams online devices from discovery services.
3. `SendTab` validates selected files and dispatches send use cases.
4. `TransferBloc` handles incoming requests, progress updates, and saved-file events.
5. `SettingsBloc` manages device name and notification preferences.

## Project structure

```text
lib/
	main.dart
	di/
		service_locator.dart
	presentation/
		bloc/
			app_init/
			ads/
			discovery/
			transfer/
			settings/
		pages/
			home_page.dart
			home_tab.dart
			tabs/
				send_tab.dart
				receive_tab.dart
				settings_tab.dart
		widgets/
			common/
			home/
			send/
			receive/
			settings/
			transfer/
	domain/
		entities/
		repositories/
		usecases/
			app_init/
			ads/
			discovery/
			transfer/
			settings/
			device_info/
			file_access/
	data/
		datasources/
			app_init/
			device/
			device_info/
			file_access/
			notification/
			permission/
			settings/
			transfer/
		models/
		repositories/
	services/
		background_service.dart
		device_discovery_service.dart
		file_transfer_service.dart
		media_store_service.dart
		notification_service.dart
		permission_service.dart
```

## Getting started

### Prerequisites

- Flutter stable SDK (`flutter doctor` should be clean)
- Platform toolchain for your target device(s)

### Run

```bash
flutter pub get
flutter run -d <device-id>
```

Useful targets:

- macOS: `flutter run -d macos`
- iOS simulator/device: `flutter run -d <ios-device-id>`
- Android: `flutter run -d <android-device-id>`

## Platform behavior

### Android

- Uses MediaStore/file APIs depending on Android version.
- Requests runtime permissions as needed.

### iOS

- Discovery works via Bonjour/local network.
- Files are received in app-accessible storage; media can be saved to Photos when permitted.
- Running on a physical iPhone requires valid signing/team setup in Xcode.

### macOS

- LAN discovery and transfer services run locally.
- Received files are saved using desktop file APIs.
- Ad banner is not used on macOS.

## Testing

Run all tests:

```bash
flutter test
```

This repository includes tests for BLoCs and presentation/data helpers (see `test/`).

## Troubleshooting

- Device not found: verify both devices are on the same LAN/Wi-Fi and app is active.
- iOS physical device build fails: open Xcode, select a valid Team, and ensure bundle identifier/profile are valid.
- Transfer request fails: check firewall/network isolation and retry with both apps in foreground.

## Tech stack

- Flutter + Dart
- `flutter_bloc`, `equatable`, `get_it`
- `file_picker`, `wechat_assets_picker`, `photo_manager`, `gal`
- `bonsoir`, `multicast_dns`, `network_info_plus`, `connectivity_plus`
- `permission_handler`, `shared_preferences`, `open_file`
- `awesome_notifications`, `flutter_inappwebview`, `google_mobile_ads`

## License

No license has been defined yet.
