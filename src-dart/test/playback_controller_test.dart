import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/localization/app_strings.dart';
import 'package:observideo/services/playback_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStrings strings;

  setUpAll(() async {
    strings = await AppStrings.load();
  });

  test('goTo selects slot zero and pauses at selected interval end', () async {
    final backend = _FakePlaybackBackend();
    final completed = <int>[];
    final controller = MediaKitPlaybackController(
      strings: strings,
      backend: backend,
      onIntervalCompleted: completed.add,
    );
    addTearDown(controller.dispose);
    await controller.open(
      '/video.mp4',
      durationMs: 31000,
      intervalMs: 15000,
      startIndex: 0,
    );
    expect(controller.selected, 0);

    backend.emitPosition(0); // seek target settled
    await controller.play();
    backend.emitPosition(14999);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isEmpty);
    backend.emitPosition(15000);
    await Future<void>.delayed(Duration.zero);
    expect(completed, <int>[0]);
    expect(controller.selectedCompleted, isTrue);
  });

  test('play after completion advances, while last interval waits', () async {
    final backend = _FakePlaybackBackend();
    final controller = MediaKitPlaybackController(
      strings: strings,
      backend: backend,
    );
    addTearDown(controller.dispose);
    await controller.open(
      '/video.mp4',
      durationMs: 31000,
      intervalMs: 15000,
      startIndex: 0,
    );
    await controller.play();
    backend.emitCompleted();
    await Future<void>.delayed(Duration.zero);
    await controller.play();
    expect(controller.selected, 1);

    await controller.goTo(2);
    await controller.play();
    backend.emitCompleted();
    await Future<void>.delayed(Duration.zero);
    final playCalls = backend.playCalls;
    await controller.play();
    expect(controller.selected, 2);
    expect(backend.playCalls, playCalls);
  });

  test('stale positions after a seek cannot complete the interval', () async {
    final backend = _FakePlaybackBackend();
    final completed = <int>[];
    final controller = MediaKitPlaybackController(
      strings: strings,
      backend: backend,
      onIntervalCompleted: completed.add,
    );
    addTearDown(controller.dispose);
    await controller.open(
      '/video.mp4',
      durationMs: 45000,
      intervalMs: 15000,
      startIndex: 0,
    );
    await controller.goTo(1);
    await controller.play();
    backend.emitPosition(44000); // stale value from before the seek settled
    await Future<void>.delayed(Duration.zero);
    expect(completed, isEmpty);
    backend.emitPosition(15000);
    backend.emitPosition(30000);
    await Future<void>.delayed(Duration.zero);
    expect(completed, <int>[1]);
  });
}

final class _FakePlaybackBackend implements PlaybackBackend {
  final positions = StreamController<int>.broadcast();
  final playing = StreamController<bool>.broadcast();
  final completed = StreamController<bool>.broadcast();
  final errorOutput = StreamController<String>.broadcast();
  int currentPosition = 0;
  bool currentPlaying = false;
  int playCalls = 0;

  @override
  Stream<int> get positionChanges => positions.stream;
  @override
  Stream<bool> get playingChanges => playing.stream;
  @override
  Stream<bool> get completedChanges => completed.stream;
  @override
  Stream<String> get errors => errorOutput.stream;
  @override
  int get positionMs => currentPosition;
  @override
  bool get isPlaying => currentPlaying;

  @override
  Future<void> open(String path) async {}
  @override
  Future<void> pause() async {
    currentPlaying = false;
    playing.add(false);
  }

  @override
  Future<void> play() async {
    playCalls++;
    currentPlaying = true;
    playing.add(true);
  }

  @override
  Future<void> seek(int positionMs) async => currentPosition = positionMs;
  @override
  Future<void> useSoftwareDecoding(String path, int positionMs) async {}

  void emitPosition(int value) {
    currentPosition = value;
    positions.add(value);
  }

  void emitCompleted() => completed.add(true);

  @override
  Future<void> dispose() async {
    await positions.close();
    await playing.close();
    await completed.close();
    await errorOutput.close();
  }
}
