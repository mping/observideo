#include "include/media_kit_libs_linux/media_kit_libs_linux_plugin.h"

#include <clocale>

extern "C" void media_kit_libs_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  (void)registrar;
  // libmpv refuses to create a handle unless LC_NUMERIC is "C", and
  // media_kit_video then dereferences the NULL handle. GTK has already
  // applied the user's locale by the time plugins register.
  setlocale(LC_NUMERIC, "C");
}
