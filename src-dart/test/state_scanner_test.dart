import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/domain/default_template.dart';
import 'package:observideo/domain/models.dart';
import 'package:observideo/platform/native_platform_files.dart';
import 'package:observideo/services/media_probe.dart';
import 'package:observideo/services/state_store.dart';
import 'package:observideo/services/video_scanner.dart';

void main() {
  test('state lock excludes another store until it is released', () async {
    final directory = await Directory.systemTemp.createTemp('observideo-lock-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/state.json';
    final first = JsonStateStore(path);
    await first.acquireLock();
    addTearDown(first.close);

    final rejected = await Process.run(_dartExecutable(), <String>[
      'test/helpers/lock_probe.dart',
      '$path.lock',
    ]);
    expect(
      rejected.exitCode,
      73,
      reason: '${rejected.stdout}${rejected.stderr}',
    );
    await first.close();
    final accepted = await Process.run(_dartExecutable(), <String>[
      'test/helpers/lock_probe.dart',
      '$path.lock',
    ]);
    expect(
      accepted.exitCode,
      0,
      reason: '${accepted.stdout}${accepted.stderr}',
    );
  });

  test(
    'state store round-trips and invalid save leaves prior file intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'observideo-state-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = JsonStateStore(
        '${directory.path}/nested/state.json',
        platformFiles: _TestPlatformFiles(),
      );
      await store.acquireLock();
      addTearDown(store.close);

      final good = makeDefaultDatabase()..videosFolder = '/videos';
      expect(await store.save(good), isEmpty);
      expect((await store.load())!.videosFolder, '/videos');

      final bad = Database(schemaVersion: 99);
      expect(await store.save(bad), isNotEmpty);
      expect((await store.load())!.videosFolder, '/videos');
    },
  );

  test(
    'interrupted atomic replacement leaves the previous state intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'observideo-interrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/state.json';
      final goodStore = JsonStateStore(
        path,
        platformFiles: _TestPlatformFiles(),
      );
      final original = makeDefaultDatabase()..videosFolder = '/original';
      expect(await goodStore.save(original), isEmpty);

      final failingStore = JsonStateStore(
        path,
        platformFiles: _TestPlatformFiles(failReplacement: true),
      );
      final replacement = makeDefaultDatabase()..videosFolder = '/replacement';
      await expectLater(
        failingStore.save(replacement),
        throwsA(isA<FileSystemException>()),
      );
      expect((await goodStore.load())!.videosFolder, '/original');
    },
  );

  test(
    'scanner finds supported extensions and computes streaming MD5',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'observideo-scan-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await Directory('${directory.path}/nested').create();
      await File('${directory.path}/nested/a.MP4').writeAsString('hello');
      await File('${directory.path}/ignored.txt').writeAsString('ignored');

      final progress = <String>[];
      final entries = await VideoScanner(const _FakeProbe()).scan(
        directory.path,
        onProgress: (done, total) => progress.add('$done/$total'),
      );
      expect(entries, hasLength(1));
      expect(entries.single.md5, '5d41402abc4b2a76b9719d911017c592');
      expect(entries.single.durationMs, 12345);
      expect(progress, <String>['1/1']);
    },
  );
}

String _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is required for the lock subprocess test.');
  }
  final suffix = Platform.isWindows ? '.exe' : '';
  return '$flutterRoot/bin/cache/dart-sdk/bin/dart$suffix';
}

final class _TestPlatformFiles implements PlatformFiles {
  _TestPlatformFiles({this.failReplacement = false});

  final bool failReplacement;

  @override
  void atomicReplace(String temporaryPath, String destinationPath) {
    if (failReplacement) {
      throw FileSystemException('simulated interrupted replacement');
    }
    final destination = File(destinationPath);
    if (destination.existsSync()) destination.deleteSync();
    File(temporaryPath).renameSync(destinationPath);
  }
}

final class _FakeProbe implements MediaProbe {
  const _FakeProbe();

  @override
  Future<ProbeResult> probe(String path) async =>
      const ProbeResult(durationMs: 12345);
}
