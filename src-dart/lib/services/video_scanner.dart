import 'dart:io';

import 'package:crypto/crypto.dart';

import 'media_probe.dart';

final class ScanEntry {
  const ScanEntry({
    required this.path,
    required this.size,
    required this.md5,
    required this.durationMs,
    this.probeError,
  });

  final String path;
  final int size;
  final String md5;
  final int durationMs;
  final String? probeError;

  bool get probeFailed => probeError != null;
}

typedef ScanProgress = void Function(int completed, int total);

final class VideoScanner {
  const VideoScanner(this.mediaProbe);

  final MediaProbe mediaProbe;

  static const extensions = <String>{'.mp4', '.avi', '.webm'};

  Future<List<ScanEntry>> scan(String root, {ScanProgress? onProgress}) async {
    final directory = Directory(root);
    if (!await directory.exists()) {
      throw FileSystemException('Video folder does not exist', root);
    }
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (extensions.any(lower.endsWith)) files.add(entity);
    }
    files.sort((left, right) => left.path.compareTo(right.path));

    final entries = <ScanEntry>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final stat = await file.stat();
      var digest = '';
      var durationMs = 0;
      String? error;
      try {
        digest = await md5ForFile(file.path);
        durationMs = (await mediaProbe.probe(file.path)).durationMs;
      } on Object catch (exception) {
        error = exception.toString();
      }
      entries.add(
        ScanEntry(
          path: file.absolute.path,
          size: stat.size,
          md5: digest,
          durationMs: durationMs,
          probeError: error,
        ),
      );
      onProgress?.call(index + 1, files.length);
    }
    return entries;
  }

  static Future<String> md5ForFile(String path) async {
    final sink = _DigestSink();
    final input = md5.startChunkedConversion(sink);
    await for (final chunk in File(path).openRead()) {
      input.add(chunk);
    }
    input.close();
    return sink.value.toString();
  }
}

final class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
