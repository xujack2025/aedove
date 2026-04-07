# Phase 5 Regression Checklist

Date: 2026-04-07

## Architecture Checks

- [x] `lib/pages/**` has no direct `package:aedove/services/*` import.
- [x] `lib/presentation/**` has no direct `package:aedove/services/*` import.
- [x] Page layer triggers behavior via BLoC events or use cases.
- [x] Repository interfaces remain in `domain/repositories`.
- [x] Service usage is kept behind repository/usecase adapters.

## Feature Checks

- [x] Discovery list still updates in Send tab.
- [x] Transfer request/progress flow still updates in Receive tab.
- [x] Ads rotation still driven by AdsBloc.
- [x] App startup now goes through AppInitBloc.
- [x] Settings read/write now goes through SettingsBloc.

## Test Checks

- [x] `test/app_init_bloc_test.dart` passes.
- [x] `test/settings_bloc_test.dart` passes.
- [x] `test/ads_bloc_test.dart` passes.
- [x] `test/transfer_bloc_test.dart` passes.

## Command

```bash
flutter test test/app_init_bloc_test.dart test/settings_bloc_test.dart test/ads_bloc_test.dart test/transfer_bloc_test.dart
```

Expected result: all tests pass.
