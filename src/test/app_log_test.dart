import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/services/app_log.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('observideo-log-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('keeps only the most recent entries in memory', () {
    final log = AppLog(capacity: 3);
    for (var index = 0; index < 5; index++) {
      log.info('teste', 'entrada $index');
    }
    expect(log.entries.map((entry) => entry.message), <String>[
      'entrada 2',
      'entrada 3',
      'entrada 4',
    ]);
  });

  test('file receives entries logged before and after attaching', () async {
    final log = AppLog()..info('arranque', 'antes do ficheiro');
    final path = p.join(directory.path, 'observideo', 'observideo.log');
    await log.attachFile(path);
    log.warning('dados', 'depois do ficheiro');

    expect(log.filePath, path);
    final lines = File(path).readAsLinesSync();
    expect(lines, hasLength(2));
    expect(lines[0], contains('INFO  [arranque] antes do ficheiro'));
    expect(lines[1], contains('AVISO [dados] depois do ficheiro'));
  });

  test('oversized log file is moved aside at startup', () async {
    final path = p.join(directory.path, 'observideo.log');
    File(path).writeAsStringSync('x' * (AppLog.maxFileBytes + 1));
    final log = AppLog();
    await log.attachFile(path);
    log.info('arranque', 'nova sessão');

    expect(File('$path.1').lengthSync(), AppLog.maxFileBytes + 1);
    expect(File(path).readAsLinesSync().single, contains('nova sessão'));
  });

  test('errors include the exception and stack trace', () {
    final log = AppLog();
    final stackTrace = StackTrace.current;
    log.error('dados', 'Falha', const FormatException('mau'), stackTrace);

    final entry = log.entries.single;
    expect(entry.level, LogLevel.error);
    expect(entry.message, startsWith('Falha: FormatException: mau\n'));
    expect(entry.message, contains('$stackTrace'.split('\n').first));
  });
}
