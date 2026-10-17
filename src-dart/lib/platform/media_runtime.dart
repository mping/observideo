import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef _GetModuleHandleNative = Pointer<Void> Function(Pointer<Utf16>);
typedef _GetModuleHandleDart = Pointer<Void> Function(Pointer<Utf16>);
typedef _GetModuleFileNameNative = Uint32 Function(
  Pointer<Void>,
  Pointer<Utf16>,
  Uint32,
);
typedef _GetModuleFileNameDart = int Function(
  Pointer<Void>,
  Pointer<Utf16>,
  int,
);

final class MediaRuntime {
  const MediaRuntime({required this.root});

  final String root;

  String get ffprobePath =>
      p.join(root, 'bin', Platform.isWindows ? 'ffprobe.exe' : 'ffprobe');

  String get manifestPath =>
      p.join(root, 'share', 'observideo', 'codec-manifest.json');

  // media_kit_video links libmpv into the process at startup; loading a
  // second copy gives Dart a handle whose globals the plugin can't see, and
  // mpv aborts in m_config_cache_from_shadow once a video is rendered.
  String get libmpvPath {
    if (Platform.isWindows) {
      // The plugin imports libmpv-2.dll by name, which the loader resolves
      // next to the executable. Opening media\bin\libmpv-2.dll by full path
      // maps a second instance even though the files are identical.
      final linked = _loadedModule('libmpv-2.dll');
      if (linked != null) return linked;
      final bundled = p.join(
        File(Platform.resolvedExecutable).parent.path,
        'libmpv-2.dll',
      );
      if (File(bundled).existsSync()) return bundled;
      return p.join(root, 'bin', 'libmpv-2.dll');
    }
    if (Platform.isMacOS) {
      final bundled = p.normalize(
        p.join(
          File(Platform.resolvedExecutable).parent.path,
          '..',
          'Frameworks',
          'Mpv.framework',
          'Mpv',
        ),
      );
      if (File(bundled).existsSync()) return bundled;
      final candidates = Directory(p.join(root, 'lib'))
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('libmpv'))
          .toList();
      if (candidates.isNotEmpty) return candidates.first.path;
      return p.join(root, 'lib', 'libmpv.dylib');
    }
    // Packagers such as linuxdeploy relocate the linked copy (bundle lib/ ->
    // AppDir usr/lib), so ask the process which file it actually mapped.
    final linked = _mappedLibrary('libmpv.so');
    if (linked != null) return linked;
    final bundled = p.join(
      File(Platform.resolvedExecutable).parent.path,
      'lib',
      'libmpv.so.2',
    );
    if (File(bundled).existsSync()) return bundled;
    return p.join(root, 'lib', 'libmpv.so');
  }

  static MediaRuntime resolve() {
    final override = Platform.environment['OBSERVIDEO_MEDIA_ROOT'];
    if (override != null && override.isNotEmpty) {
      return MediaRuntime(root: override);
    }

    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final platform = Platform.isMacOS
        ? 'macos'
        : Platform.isWindows
        ? 'windows'
        : 'linux';
    final architecture = _architecture();
    final development = p.normalize(
      p.join(
        Directory.current.path,
        'native',
        'media',
        'out',
        '$platform-$architecture',
      ),
    );
    final adjacent = p.join(executableDir, 'media');
    for (final candidate in <String>[development, adjacent]) {
      final runtime = MediaRuntime(root: candidate);
      if (File(runtime.ffprobePath).existsSync()) return runtime;
    }
    throw StateError(
      'Controlled media runtime not found. Run native/media/build_unix.sh '
      'or set OBSERVIDEO_MEDIA_ROOT.',
    );
  }

  void validate() {
    final missing = <String>[
      if (!File(ffprobePath).existsSync()) ffprobePath,
      if (!File(libmpvPath).existsSync()) libmpvPath,
      if (!File(manifestPath).existsSync()) manifestPath,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Controlled media runtime is incomplete: ${missing.join(', ')}',
      );
    }
  }

  static String? _mappedLibrary(String prefix) {
    final List<String> maps;
    try {
      maps = File('/proc/self/maps').readAsLinesSync();
    } on FileSystemException {
      return null;
    }
    // address perms offset dev inode pathname; the pathname may hold spaces.
    final entry = RegExp(r'^(?:\S+\s+){5}(/.*)$');
    for (final line in maps) {
      final path = entry.firstMatch(line)?.group(1);
      if (path != null && p.basename(path).startsWith(prefix)) return path;
    }
    return null;
  }

  static String? _loadedModule(String name) {
    const capacity = 32768; // longest path GetModuleFileNameW can return
    final kernel = DynamicLibrary.open('kernel32.dll');
    final getModuleHandle = kernel
        .lookupFunction<_GetModuleHandleNative, _GetModuleHandleDart>(
          'GetModuleHandleW',
        );
    final getModuleFileName = kernel
        .lookupFunction<_GetModuleFileNameNative, _GetModuleFileNameDart>(
          'GetModuleFileNameW',
        );
    final moduleName = name.toNativeUtf16();
    final buffer = calloc<Uint16>(capacity).cast<Utf16>();
    try {
      final module = getModuleHandle(moduleName);
      if (module == nullptr) return null;
      final length = getModuleFileName(module, buffer, capacity);
      // 0 is failure; a full buffer means the path was truncated.
      if (length == 0 || length >= capacity) return null;
      return buffer.toDartString(length: length);
    } finally {
      calloc.free(moduleName);
      calloc.free(buffer);
    }
  }

  static String _architecture() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return 'arm64';
    }
    return 'x64';
  }
}
