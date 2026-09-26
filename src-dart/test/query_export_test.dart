import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/domain/models.dart';
import 'package:observideo/services/export_service.dart';
import 'package:observideo/services/query_service.dart';

void main() {
  final template = ObservationTemplate(
    id: 't1',
    name: 'Demo',
    intervalMs: 15000,
    nextAttributeId: 3,
    nextValueId: 22,
    attributes: <ObservationAttribute>[
      ObservationAttribute(
        id: 1,
        name: 'Peer',
        values: <ObservationValue>[
          ObservationValue(id: 10, name: 'Alone'),
          ObservationValue(id: 11, name: 'Group, with peers'),
        ],
      ),
      ObservationAttribute(
        id: 2,
        name: 'Gender',
        values: <ObservationValue>[ObservationValue(id: 20, name: 'Same')],
      ),
    ],
  );

  test('query matches all constraints and combines prefix tallies', () {
    final service = const DartQueryService();
    final videos = <VideoRecord>[
      _video('/v/Sample_001.mp4', <Interval>[
        <int, int>{1: 10},
        <int, int>{1: 11},
      ]),
      _video('/v/Sample_002.mp4', <Interval>[
        <int, int>{1: 10},
      ]),
      _video('/v/other.mp4', <Interval>[
        <int, int>{1: 10},
      ], missing: true),
    ];
    final top = service.runQuery(
      videos,
      't1',
      QueryAggregator.byPrefix,
      <int, int?>{1: 10},
    );
    final bottom = service.runQuery(
      videos,
      't1',
      QueryAggregator.byPrefix,
      <int, int?>{1: null},
    );
    final rows = service.combine(top, bottom);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Sample_0');
    expect(rows.single.topMatched, 2);
    expect(rows.single.bottomMatched, 3);
    expect(rows.single.total, 3);
  });

  test('video CSV is RFC 4180 with milliseconds and no blank first row', () {
    final annotation = Annotation(
      templateId: 't1',
      intervalMs: 15000,
      intervals: <Interval>[
        <int, int>{1: 11, 2: 20},
        <int, int>{1: 10},
        <int, int>{},
      ],
    );
    final csv = DartExportService().buildVideoCsv(
      template,
      31000,
      annotation,
      ExportValueMode.name,
    );
    final lines = csv.split('\r\n');
    expect(lines[0], 'Interval,Start (s),End (s),Peer,Gender');
    expect(lines[1], '1,0.000,15.000,"Group, with peers",Same');
    expect(lines[3], '3,30.000,31.000,,');
  });

  test('ZIP export uses deterministic collision-safe names', () async {
    final directory = await Directory.systemTemp.createTemp(
      'observideo-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = Database(
      videosFolder: '/videos',
      templates: <ObservationTemplate>[template],
      videos: <VideoRecord>[
        _video('/videos/a/b.mp4', <Interval>[
          <int, int>{1: 10},
        ]),
        _video('/videos/a_b.mp4', <Interval>[
          <int, int>{1: 10},
        ]),
      ],
    );
    final output = '${directory.path}/out.zip';
    final result = await DartExportService().exportAllToZip(
      database,
      ExportValueMode.name,
      output,
    );
    expect(result.ok, isTrue, reason: result.error);
    final archive = ZipDecoder().decodeBytes(await File(output).readAsBytes());
    expect(archive.files.map((file) => file.name).toSet(), <String>{
      'a_b.mp4.csv',
      'a_b.mp4-2.csv',
    });
  });
}

VideoRecord _video(
  String path,
  List<Interval> intervals, {
  bool missing = false,
}) => VideoRecord(
  path: path,
  durationMs: intervals.length * 15000,
  missing: missing,
  annotation: Annotation(
    templateId: 't1',
    intervalMs: 15000,
    intervals: intervals,
  ),
);
