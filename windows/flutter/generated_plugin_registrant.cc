//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <awesome_notifications/awesome_notifications_plugin_c_api.h>
#include <bonsoir_windows/bonsoir_windows_plugin_c_api.h>
#include <connectivity_plus/connectivity_plus_windows_plugin.h>
#include <file_selector_windows/file_selector_windows.h>
#include <gal/gal_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AwesomeNotificationsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AwesomeNotificationsPluginCApi"));
  BonsoirWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BonsoirWindowsPluginCApi"));
  ConnectivityPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  GalPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GalPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
