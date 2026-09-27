import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/domain/default_template.dart';
import 'package:observideo/domain/models.dart';
import 'package:observideo/localization/app_strings.dart';
import 'package:observideo/services/app_controller.dart';
import 'package:observideo/services/export_service.dart';
import 'package:observideo/services/media_probe.dart';
import 'package:observideo/services/query_service.dart';
import 'package:observideo/services/state_store.dart';
import 'package:observideo/services/video_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStrings strings;

  setUpAll(() async {
    strings = await AppStrings.load();
  });

  test('template mutations use monotonic IDs and clear deleted values', () {
    final controller = _controller(strings);
    addTearDown(controller.dispose);
    final template = controller.database.templates.single;
    final attributeId = controller.addAttribute(template.id, 'New attribute');
    final firstValueId = controller.addValue(template.id, attributeId, 'One');
    final secondValueId = controller.addValue(template.id, attributeId, 'Two');
    expect(secondValueId, greaterThan(firstValueId));

    controller.database.videos.add(
      VideoRecord(
        path: '/video.mp4',
        durationMs: 1000,
        annotation: Annotation(
          templateId: template.id,
          intervalMs: 15000,
          intervals: <Interval>[
            <int, int>{attributeId: firstValueId},
          ],
        ),
      ),
    );
    expect(
      controller.valueUsageCount(template.id, attributeId, firstValueId),
      1,
    );
    controller.deleteValue(template.id, attributeId, firstValueId);
    expect(
      controller.database.videos.single.annotation!.intervals.single,
      isEmpty,
    );
    expect(template.nextValueId, greaterThan(secondValueId));
  });

  test('template deletion is blocked while any video uses it', () {
    final controller = _controller(strings);
    addTearDown(controller.dispose);
    final template = controller.database.templates.single;
    controller.database.videos.add(
      VideoRecord(
        path: '/video.mp4',
        durationMs: 1000,
        annotation: Annotation(
          templateId: template.id,
          intervalMs: 15000,
          intervals: <Interval>[<int, int>{}],
        ),
      ),
    );
    expect(controller.deleteTemplate(template.id), isFalse);
    expect(controller.database.templates, hasLength(1));
    controller.clearTemplate('/video.mp4');
    expect(controller.deleteTemplate(template.id), isTrue);
    expect(controller.database.templates, isEmpty);
  });

  test('changing a template keeps each existing video interval frozen', () {
    final controller = _controller(strings);
    addTearDown(controller.dispose);
    final template = controller.database.templates.single;
    controller.database.videos.add(
      VideoRecord(path: '/video.mp4', durationMs: 31000),
    );
    expect(controller.applyTemplate('/video.mp4', template.id), isNull);
    final annotation = controller.database.videos.single.annotation!;
    expect(annotation.intervalMs, 15000);
    expect(annotation.intervals, hasLength(3));
    controller.setTemplateInterval(template.id, 5000);
    expect(annotation.intervalMs, 15000);
    expect(annotation.intervals, hasLength(3));
  });
}

AppController _controller(AppStrings strings) {
  final controller = AppController(
    store: _MemoryStateStore(),
    scanner: VideoScanner(const _NoProbe()),
    exportService: DartExportService(strings: strings),
    queryService: const DartQueryService(),
    strings: strings,
  );
  controller
    ..database = makeDefaultDatabase(strings)
    ..initialized = true;
  return controller;
}

final class _MemoryStateStore implements StateStore {
  @override
  String get filePath => 'memory';
  @override
  Future<void> acquireLock() async {}
  @override
  Future<void> close() async {}
  @override
  Future<Database?> load() async => null;
  @override
  Future<List<String>> save(Database database) async => const <String>[];
}

final class _NoProbe implements MediaProbe {
  const _NoProbe();

  @override
  Future<ProbeResult> probe(String path) async =>
      const ProbeResult(durationMs: 1);
}
