import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/domain/default_template.dart';
import 'package:observideo/domain/interval_model.dart';
import 'package:observideo/domain/models.dart';
import 'package:observideo/domain/validation.dart';
import 'package:observideo/localization/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStrings strings;

  setUpAll(() async {
    strings = await AppStrings.load();
  });

  test('schema v1 JSON round-trips exactly', () {
    final database = makeDefaultDatabase(strings)..videosFolder = '/videos';
    final template = database.templates.single;
    database.videos.add(
      VideoRecord(
        path: '/videos/a.mp4',
        size: 42,
        md5: 'deadbeef',
        durationMs: 21000,
        annotation: Annotation(
          templateId: template.id,
          intervalMs: 15000,
          lastInterval: 1,
          intervals: <Interval>[
            <int, int>{1: 1},
            <int, int>{},
          ],
        ),
      ),
    );

    final encoded = jsonEncode(database.toJson());
    final decoded = Database.fromJson(jsonDecode(encoded));
    expect(jsonEncode(decoded.toJson()), encoded);
    expect(validateDatabase(decoded), isEmpty);
  });

  test('annotation null keeps the documented shape', () {
    final database = Database(
      videos: <VideoRecord>[VideoRecord(path: '/x.mp4')],
    );
    expect(database.toJson()['videos'], <Object?>[
      <String, Object?>{
        'path': '/x.mp4',
        'size': 0,
        'md5': '',
        'durationMs': 0,
        'missing': false,
        'annotation': null,
      },
    ]);
  });

  test('validation rejects unknown values and incorrect interval counts', () {
    final database = makeDefaultDatabase(strings);
    database.videos.add(
      VideoRecord(
        path: '/a.mp4',
        durationMs: 31000,
        annotation: Annotation(
          templateId: database.templates.single.id,
          intervalMs: 15000,
          intervals: <Interval>[
            <int, int>{1: 9999},
          ],
        ),
      ),
    );
    final errors = validateDatabase(database);
    expect(
      errors.any((error) => error.contains('expected 3 intervals')),
      isTrue,
    );
    expect(errors.any((error) => error.contains('unknown value id')), isTrue);
  });

  test('default template has stable identity and monotonic IDs', () {
    final template = makeDemoTemplate(strings);
    expect(template.id, 'fb52dd46-85cc-4864-b11e-44b8a5b28331');
    expect(template.name, 'Observação BLP');
    expect(template.attributes, hasLength(8));
    final attributeIds = template.attributes.map((value) => value.id).toSet();
    final valueIds = template.attributes
        .expand((attribute) => attribute.values)
        .map((value) => value.id)
        .toSet();
    expect(
      template.nextAttributeId,
      greaterThan(attributeIds.reduce((a, b) => a > b ? a : b)),
    );
    expect(
      template.nextValueId,
      greaterThan(valueIds.reduce((a, b) => a > b ? a : b)),
    );
  });

  test('interval math includes slot zero and a short final interval', () {
    expect(IntervalModel.intervalCount(31000, 15000), 3);
    expect(IntervalModel.indexForScrub(0, 15000, 3), 0);
    expect(IntervalModel.indexForScrub(15000, 15000, 3), 1);
    expect(IntervalModel.endMs(2, 31000, 15000), 31000);
    expect(IntervalModel.reachedEnd(30500, 2, 31000, 15000), isFalse);
    expect(IntervalModel.reachedEnd(31000, 2, 31000, 15000), isTrue);
  });
}
