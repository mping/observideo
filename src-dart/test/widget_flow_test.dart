import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/domain/default_template.dart';
import 'package:observideo/domain/models.dart';
import 'package:observideo/main.dart';
import 'package:observideo/services/app_controller.dart';
import 'package:observideo/services/export_service.dart';
import 'package:observideo/services/media_probe.dart';
import 'package:observideo/services/query_service.dart';
import 'package:observideo/services/state_store.dart';
import 'package:observideo/services/video_scanner.dart';
import 'package:observideo/ui/annotation_table.dart';

void main() {
  testWidgets('desktop shell exposes all workflows', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ObservideoApp(controller: controller));

    expect(find.text('Videos'), findsWidgets);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Queries'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('No videos discovered yet.'), findsOneWidget);
  });

  testWidgets('a template can be created from the Templates screen', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ObservideoApp(controller: controller));
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New template'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Field study');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      controller.database.templates.map((item) => item.name),
      contains('Field study'),
    );
    expect(find.text('Field study'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('annotation values use the original clickable column table', (
    tester,
  ) async {
    final template = makeDemoTemplate();
    final interval = <int, int>{};
    AttributeId? changedAttribute;
    ValueId? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: observideoTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey<String>('annotation-table-host'),
              width: 700,
              child: AnnotationTable(
                template: template,
                interval: interval,
                onChanged: (attributeId, valueId) {
                  changedAttribute = attributeId;
                  changedValue = valueId;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButton<int?>), findsNothing);
    for (final attribute in template.attributes) {
      expect(find.text(attribute.name), findsOneWidget);
    }
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('annotation-table')))
          .width,
      tester
          .getSize(find.byKey(const ValueKey<String>('annotation-table-host')))
          .width,
    );
    final attribute = template.attributes.first;
    final value = attribute.values.first;
    final valueCell = find.byKey(
      ValueKey<String>('annotation-${attribute.id}-${value.id}'),
    );
    final valuePadding = tester.widget<Padding>(
      find.descendant(of: valueCell, matching: find.byType(Padding)),
    );
    expect(valuePadding.padding, const EdgeInsets.all(1));
    expect(
      tester.widget<Text>(find.text(value.name)).style!.fontSize,
      lessThan(11),
    );
    await tester.tap(valueCell);
    expect(changedAttribute, attribute.id);
    expect(changedValue, value.id);

    interval[attribute.id] = value.id;
    await tester.pumpWidget(
      MaterialApp(
        theme: observideoTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: AnnotationTable(
                template: template,
                interval: interval,
                onChanged: (attributeId, valueId) {
                  changedAttribute = attributeId;
                  changedValue = valueId;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('annotation-${attribute.id}-${value.id}')),
    );
    expect(changedValue, isNull);
  });

  testWidgets('application theme uses a smaller overall type scale', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(ObservideoApp(controller: controller));
    final context = tester.element(find.text('No videos discovered yet.'));
    expect(Theme.of(context).textTheme.bodyMedium!.fontSize, lessThan(14));
  });
}

AppController _controller() {
  final controller = AppController(
    store: _MemoryStateStore(),
    scanner: VideoScanner(const _FakeProbe()),
    exportService: DartExportService(),
    queryService: const DartQueryService(),
  );
  controller
    ..database = makeDefaultDatabase()
    ..initialized = true;
  return controller;
}

final class _MemoryStateStore implements StateStore {
  Database? database;

  @override
  String get filePath => 'memory';
  @override
  Future<void> acquireLock() async {}
  @override
  Future<void> close() async {}
  @override
  Future<Database?> load() async => database;
  @override
  Future<List<String>> save(Database database) async {
    this.database = database;
    return const <String>[];
  }
}

final class _FakeProbe implements MediaProbe {
  const _FakeProbe();

  @override
  Future<ProbeResult> probe(String path) async =>
      const ProbeResult(durationMs: 1000);
}
