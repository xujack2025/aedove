import 'package:aedove/di/service_locator.dart';
import 'package:aedove/domain/usecases/device_info/get_local_ip_address_usecase.dart';
import 'package:aedove/presentation/bloc/settings/settings_bloc.dart';
import 'package:aedove/presentation/bloc/settings/settings_event.dart';
import 'package:aedove/presentation/bloc/settings/settings_state.dart';
import 'package:aedove/presentation/widgets/common/snackbar_helper.dart';
import 'package:aedove/presentation/pages/tabs/settings_action_helper.dart';
import 'package:aedove/presentation/widgets/settings/settings_section_card.dart';
import 'package:aedove/presentation/widgets/settings/settings_info_tile.dart';
import 'package:aedove/presentation/widgets/settings/settings_switch_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final GetLocalIpAddressUsecase _getLocalIpAddressUsecase =
      sl<GetLocalIpAddressUsecase>();

  String _ipAddress = 'Unknown';

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    try {
      final ipAddress = await _getLocalIpAddressUsecase();

      if (mounted) {
        setState(() {
          _ipAddress = ipAddress;
        });
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        SnackBarHelper.showError(context, state.errorMessage!);
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your device and preferences',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                ),
              ),
              const SizedBox(height: 32),
              SettingsSectionCard(
                title: 'Device Information',
                icon: Icons.devices_other_rounded,
                children: [
                  SettingsInfoTile(
                    icon: Icons.edit_rounded,
                    iconColor: Colors.blue,
                    title: 'Device Name',
                    subtitle: Text(state.deviceName),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => SettingsActionHelper.showDeviceNameDialog(
                      context: context,
                      currentName: state.deviceName,
                      onSave: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsDeviceNameChanged(value),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  SettingsInfoTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: Colors.purple,
                    title: 'Device ID',
                    subtitle: Text(
                      state.deviceId,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const Divider(height: 24),
                  SettingsInfoTile(
                    icon: Icons.wifi_rounded,
                    iconColor: Colors.orange,
                    title: 'IP Address',
                    subtitle: Text(
                      _ipAddress,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsSectionCard(
                title: 'Preferences',
                icon: Icons.tune_rounded,
                children: [
                  SettingsSwitchTile(
                    value: state.notificationsEnabled,
                    title: 'Notifications',
                    subtitle: 'Show alerts for file transfers',
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            context.read<SettingsBloc>().add(
                              SettingsNotificationsToggled(value),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsSectionCard(
                title: 'Contact Us',
                icon: Icons.contact_mail_rounded,
                children: [
                  SettingsInfoTile(
                    icon: Icons.campaign_rounded,
                    iconColor: Colors.green,
                    title: 'Advertise With Us',
                    subtitle: const Text('Post your ads in our app'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => SettingsActionHelper.openContactPage(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsSectionCard(
                title: 'About',
                icon: Icons.info_outline_rounded,
                children: [
                  SettingsInfoTile(
                    icon: Icons.verified_rounded,
                    iconColor: Colors.teal,
                    title: 'Version',
                    subtitle: const Text('1.1.1'),
                  ),
                  const Divider(height: 24),
                  SettingsInfoTile(
                    icon: Icons.description_rounded,
                    iconColor: Colors.indigo,
                    title: 'Description',
                    subtitle: const Text('Automated WiFi file sharing app'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
