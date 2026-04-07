import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.isLoading = false,
    this.deviceName = 'My Device',
    this.deviceId = 'Unknown',
    this.notificationsEnabled = true,
    this.errorMessage,
  });

  final bool isLoading;
  final String deviceName;
  final String deviceId;
  final bool notificationsEnabled;
  final String? errorMessage;

  SettingsState copyWith({
    bool? isLoading,
    String? deviceName,
    String? deviceId,
    bool? notificationsEnabled,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    deviceName,
    deviceId,
    notificationsEnabled,
    errorMessage,
  ];
}
