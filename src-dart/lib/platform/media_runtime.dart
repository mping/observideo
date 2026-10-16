import 'dart:io';

import 'package:path/path.dart' as p;

final class MediaRuntime {
  const MediaRuntime({required this.root});

  final String root;

  String get ffprobePath =>
      p.join(root, 'bin', Platform.isWindows ? 'ffprobe.exe' : 'ffprobe');

  String get libmpvPath {
    if (Platform.isWindows) return p.join(root, 'bin', 'libmpv-2.dll');
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
    // media_kit_video links the bundled copy; loading a second copy from the
    // media root gives Dart a handle whose globals the plugin can't see.
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
      if (!File(p.join(root, 'share', 'observideo', 'codec-manifest.json'))
          .existsSync())
        p.join(root, 'share', 'observideo', 'codec-manifest.json'),
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Controlled media runtime is incomplete: ${missing.join(', ')}',
      );
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
