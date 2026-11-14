cmake_minimum_required(VERSION 3.13)
set(PROJECT_NAME "media_kit_libs_linux")
project(${PROJECT_NAME} LANGUAGES CXX)

option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit controlled libraries are available" ON)
if(NOT DEFINED ENV{OBSERVIDEO_MEDIA_ROOT})
  message(FATAL_ERROR "OBSERVIDEO_MEDIA_ROOT must point at the controlled Linux media build")
endif()
file(TO_CMAKE_PATH "$ENV{OBSERVIDEO_MEDIA_ROOT}" MEDIA_ROOT)
if(NOT EXISTS "${MEDIA_ROOT}/lib")
  message(FATAL_ERROR "Controlled media libraries are missing from ${MEDIA_ROOT}/lib")
endif()

# media_kit_video (configured after this plugin) finds libmpv via pkg-config;
# point it at the controlled build instead of any system libmpv.
if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
  set(ENV{PKG_CONFIG_PATH} "${MEDIA_ROOT}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
else()
  set(ENV{PKG_CONFIG_PATH} "${MEDIA_ROOT}/lib/pkgconfig")
endif()

set(PLUGIN_NAME "media_kit_libs_linux_plugin")
add_library(${PLUGIN_NAME} SHARED
  "media_kit_libs_linux_plugin.cc"
  "include/media_kit_libs_linux/media_kit_libs_linux_plugin.h")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
# Plugins carry only $ORIGIN at runtime (see linux/CMakeLists.txt), so the
# runner's link step needs the controlled libmpv location spelled out.
target_link_options(${PLUGIN_NAME} INTERFACE "-Wl,-rpath-link,${MEDIA_ROOT}/lib")

file(GLOB CONTROLLED_LIBRARIES "${MEDIA_ROOT}/lib/*.so*")
set(media_kit_libs_linux_bundled_libraries ${CONTROLLED_LIBRARIES} PARENT_SCOPE)
