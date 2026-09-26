import 'dart:convert';
import 'dart:io';

final class ProbeResult {
  const ProbeResult({
    required this.durationMs,
    this.codec = '',
    this.width,
    this.height,
    this.frameRate,
  });

  final int durationMs;
  final String codec;
  final int? width;
  final int? height;
  final double? frameRate;
}

abstract interface class MediaProbe {
  Future<ProbeResult> probe(String path);
}

final class FfprobeMediaProbe implements MediaProbe {
  const FfprobeMediaProbe(this.executable);

  final String executable;

  @override
  Future<ProbeResult> probe(String path) async {
    final result = await Process.run(executable, <String>[
      '-v',
      'error',
      '-show_entries',
      'format=duration:stream=index,codec_type,codec_name,width,height,avg_frame_rate',
      '-of',
      'json',
      path,
    ]);
    if (result.exitCode != 0) {
      throw FormatException(
        'ffprobe failed for $path: ${(result.stderr as String).trim()}',
      );
    }

    final decoded = jsonDecode(result.stdout as String);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('ffprobe returned malformed JSON');
    }
    final format = decoded['format'];
    var durationMs = format is Map<String, Object?>
        ? _durationToMs(format['duration'])
        : 0;
    if (durationMs <= 0) durationMs = await _durationFromPackets(path);
    if (durationMs <= 0) {
      throw FormatException('Could not determine the duration of $path');
    }

    Map<String, Object?>? videoStream;
    final streams = decoded['streams'];
    if (streams is List<Object?>) {
      for (final stream in streams) {
        if (stream is Map<String, Object?> && stream['codec_type'] == 'video') {
          videoStream = stream;
          break;
        }
      }
    }
    return ProbeResult(
      durationMs: durationMs,
      codec: videoStream?['codec_name'] as String? ?? '',
      width: (videoStream?['width'] as num?)?.toInt(),
      height: (videoStream?['height'] as num?)?.toInt(),
      frameRate: _parseFrameRate(videoStream?['avg_frame_rate']),
    );
  }

  Future<int> _durationFromPackets(String path) async {
    final result = await Process.run(executable, <String>[
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_packets',
      '-show_entries',
      'packet=pts_time,duration_time',
      '-of',
      'csv=p=0',
      path,
    ]);
    if (result.exitCode != 0) return 0;
    var maxSeconds = 0.0;
    for (final line in const LineSplitter().convert(result.stdout as String)) {
      final cells = line.split(',');
      if (cells.isEmpty) continue;
      final start = double.tryParse(cells[0]) ?? 0;
      final duration = cells.length > 1 ? double.tryParse(cells[1]) ?? 0 : 0;
      if (start + duration > maxSeconds) maxSeconds = start + duration;
    }
    return (maxSeconds * 1000).round();
  }

  static int _durationToMs(Object? value) {
    final seconds = value is num ? value.toDouble() : double.tryParse('$value');
    return seconds == null || !seconds.isFinite ? 0 : (seconds * 1000).round();
  }

  static double? _parseFrameRate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final parts = value.split('/');
    if (parts.length == 1) return double.tryParse(value);
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }
}
