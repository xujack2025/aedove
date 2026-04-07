import 'package:aedove/presentation/widgets/common/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsActionHelper {
  const SettingsActionHelper._();

  static const String contactUrl = 'https://aedove.com/contact.html';

  static Future<void> showDeviceNameDialog({
    required BuildContext context,
    required String currentName,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            hintText: 'Enter device name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static Future<void> openContactPage(BuildContext context) async {
    final uri = Uri.parse(contactUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      if (context.mounted) {
        SnackBarHelper.showError(context, 'Could not open contact page');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Error opening contact page');
      }
    }
  }
}
