class SettingsEntity {
  const SettingsEntity({
    required this.deviceName,
    required this.deviceId,
    required this.notificationsEnabled,
  });

  final String deviceName;
  final String deviceId;
  final bool notificationsEnabled;

  SettingsEntity copyWith({
    String? deviceName,
    String? deviceId,
    bool? notificationsEnabled,
  }) {
    return SettingsEntity(
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
