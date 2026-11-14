import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

final class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime time;
  final LogLevel level;
  final String source;
  final String message;

  /// Local wall-clock time with milliseconds, e.g. `14:03:27.512`.
  String get clock =>
      '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}.'
      '${time.millisecond.toString().padLeft(3, '0')}';

  @override
  String toString() {
    final date = '${time.year}-${_two(time.month)}-${_two(time.day)}';
    final label = switch (level) {
      LogLevel.info => 'INFO ',
      LogLevel.warning => 'AVISO',
      LogLevel.error => 'ERRO ',
    };
    return '$date $clock $label [$source] $message';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Application-wide diagnostic log shown on the diagnostics screen.
///
/// Entries are also appended to a file as they happen, so the events leading
/// up to a native crash (which takes the in-memory log with it) are kept.
final class AppLog extends ChangeNotifier {
  AppLog({this.capacity = 5000});

  static final instance = AppLog();

  /// Size above which the log file is moved to `<path>.1` at startup.
  static const maxFileBytes = 1 << 20;

  final int capacity;
  final _entries = ListQueue<LogEntry>();
  RandomAccessFile? _file;
  String? _filePath;
  var _notifyScheduled = false;

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);
  String? get filePath => _filePath;

  void info(String source, String message) =>
      _add(LogLevel.info, source, message);

  void warning(String source, String message) =>
      _add(LogLevel.warning, source, message);

  void error(
    String source,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final details = StringBuffer(message);
    if (error != null) details.write(': $error');
    if (stackTrace != null) details.write('\n$stackTrace');
    _add(LogLevel.error, source, details.toString());
  }

  /// Starts appending to [path], first writing the entries logged so far.
  Future<void> attachFile(String path) async {
    if (_file != null) return;
    final file = File(path);
    try {
      await file.parent.create(recursive: true);
      if (await file.exists() && await file.length() > maxFileBytes) {
        try {
          await file.rename('$path.1');
        } on FileSystemException {
          // Another instance may hold the file open; keep appending to it.
        }
      }
      final handle = await file.open(mode: FileMode.append);
      for (final entry in _entries) {
        handle.writeStringSync('$entry\n');
      }
      _file = handle;
      _filePath = path;
      notifyListeners();
    } on Object catch (exception) {
      warning('registo', 'Não foi possível abrir o ficheiro $path: $exception');
    }
  }

  void _add(LogLevel level, String source, String message) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    _entries.add(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    debugPrint('$entry');
    final file = _file;
    if (file != null) {
      try {
        // Unbuffered, so the line reaches the OS before a possible crash.
        file.writeStringSync('$entry\n');
      } on Object {
        _file = null;
      }
    }
    // Entries can arrive mid-build (e.g. from FlutterError.onError), so
    // listeners hear about them once the current frame work is done.
    if (!_notifyScheduled) {
      _notifyScheduled = true;
      scheduleMicrotask(() {
        _notifyScheduled = false;
        notifyListeners();
      });
    }
  }
}
