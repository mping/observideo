import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:observideo/platform/media_runtime.dart';
import 'package:observideo/services/media_probe.dart';
import 'package:observideo/services/playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final saraPath = Platform.environment['OBSERVIDEO_SARA_MP4'];
  final externalFixtures = <String, String>{
    'H.264': 'OBSERVIDEO_H264_MP4',
    'HEVC': 'OBSERVIDEO_HEVC_MP4',
    'AV1': 'OBSERVIDEO_AV1_MP4',
    'variable-frame-rate': 'OBSERVIDEO_VFR_MP4',
    'unusual-timebase': 'OBSERVIDEO_UNUSUAL_TIMEBASE_MP4',
  };

  testWidgets('bundled MPEG-4 Part 2 fixture decodes a visible frame', (
    tester,
  ) async {
    final encoded = await File(
      'integration_test/fixtures/mpeg4_part2_red.mp4.b64',
    ).readAsString();
    final directory = await Directory.systemTemp.createTemp(
      'observideo-codec-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final fixture = File('${directory.path}/mpeg4_part2_red.mp4');
    await fixture.writeAsBytes(
      base64Decode(encoded.replaceAll(RegExp(r'\s'), '')),
    );
    await verifyPlayback(tester, fixture.path);
  });

  testWidgets(
    'Sara.MP4 decodes a non-black video frame with software fallback available',
    (tester) async {
      await verifyPlayback(tester, saraPath!);
    },
    skip: saraPath == null,
  );

  for (final fixture in externalFixtures.entries) {
    final path = Platform.environment[fixture.value];
    testWidgets(
      '${fixture.key} fixture decodes a visible frame',
      (tester) async => verifyPlayback(tester, path!),
      skip: path == null,
    );
  }

  testWidgets('damaged media is rejected with a useful probe error', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'observideo-damaged-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final damaged = File('${directory.path}/damaged.mp4');
    await damaged.writeAsBytes(<int>[
      ...ascii.encode('not an mp4 container'),
      ...List<int>.filled(128, 0),
    ]);

    final runtime = MediaRuntime.resolve()..validate();
    final probe = FfprobeMediaProbe(runtime.ffprobePath);
    await expectLater(
      probe.probe(damaged.path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('ffprobe failed'),
        ),
      ),
    );
  });
}

Future<void> verifyPlayback(WidgetTester tester, String path) async {
  final runtime = MediaRuntime.resolve()..validate();
  MediaKit.ensureInitialized(libmpv: runtime.libmpvPath);
  final probe = await FfprobeMediaProbe(runtime.ffprobePath).probe(path);
  expect(probe.durationMs, greaterThan(0));
  expect(probe.width, greaterThan(0));
  expect(probe.height, greaterThan(0));

  final backend = MediaKitPlaybackBackend();
  addTearDown(backend.dispose);
  // VideoController defers native setup to a post-frame callback, and
  // Player.open waits for it, so a frame must be pumped before awaiting.
  final opening = backend.open(path);
  await tester.pump();
  await opening;
  await backend.play();
  await tester.pump(const Duration(seconds: 2));
  await backend.pause();

  final output = backend.videoController.value!;
  await output.waitUntilFirstFrameRendered;
  final imageBytes = await backendScreenshot(backend);
  expect(imageBytes, isNotNull);
  expect(await containsVisiblePixel(imageBytes!), isTrue);
}

Future<Uint8List?> backendScreenshot(MediaKitPlaybackBackend backend) async {
  // The Player owns screenshot capture; exposing it from the backend keeps the
  // integration test tied to the same controlled libmpv instance as the UI.
  return backend.screenshot();
}

Future<bool> containsVisiblePixel(List<int> encoded) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(encoded));
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (bytes == null) return false;
  final pixels = bytes.buffer.asUint8List();
  for (var index = 0; index + 3 < pixels.length; index += 4) {
    if (pixels[index] > 8 || pixels[index + 1] > 8 || pixels[index + 2] > 8) {
      return true;
    }
  }
  return false;
}
