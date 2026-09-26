import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../domain/interval_model.dart';
import '../domain/models.dart';
import '../platform/native_platform_files.dart';
import 'query_service.dart';

enum ExportValueMode { name, oneBasedIndex }

final class ExportOutcome {
  const ExportOutcome.success() : error = null;
  const ExportOutcome.failure(this.error);

  final String? error;
  bool get ok => error == null;
}

abstract interface class ExportService {
  String buildVideoCsv(
    ObservationTemplate template,
    int durationMs,
    Annotation annotation,
    ExportValueMode mode,
  );
  Future<ExportOutcome> exportAllToZip(
    Database database,
    ExportValueMode mode,
    String outputPath,
  );
  Future<ExportOutcome> exportQueryCsv(
    List<String> topQueryRow,
    List<String> bottomQueryRow,
    List<CombinedQueryRow> rows,
    String outputPath,
  );
}

final class DartExportService implements ExportService {
  DartExportService({PlatformFiles? platformFiles})
    : _platformFiles = platformFiles ?? NativePlatformFiles();

  final PlatformFiles _platformFiles;

  static String csvEscapeField(String field) {
    if (!field.contains(RegExp('[,"\r\n]'))) return field;
    return '"${field.replaceAll('"', '""')}"';
  }

  static String csvLine(Iterable<String> fields) =>
      fields.map(csvEscapeField).join(',');

  static String _seconds(int milliseconds) =>
      (milliseconds / 1000).toStringAsFixed(3);

  @override
  String buildVideoCsv(
    ObservationTemplate template,
    int durationMs,
    Annotation annotation,
    ExportValueMode mode,
  ) {
    final attributes = template.attributes.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final lines = <String>[
      csvLine(<String>[
        'Interval',
        'Start (s)',
        'End (s)',
        ...attributes.map((attribute) => attribute.name),
      ]),
    ];
    for (var index = 0; index < annotation.intervals.length; index++) {
      final interval = annotation.intervals[index];
      final row = <String>[
        '${index + 1}',
        _seconds(IntervalModel.startMs(index, annotation.intervalMs)),
        _seconds(IntervalModel.endMs(index, durationMs, annotation.intervalMs)),
      ];
      for (final attribute in attributes) {
        final valueId = interval[attribute.id];
        if (valueId == null) {
          row.add('');
        } else if (mode == ExportValueMode.name) {
          row.add(attribute.findValue(valueId)?.name ?? '');
        } else {
          final position = attribute.values.indexWhere(
            (value) => value.id == valueId,
          );
          row.add(position < 0 ? '' : '${position + 1}');
        }
      }
      lines.add(csvLine(row));
    }
    return '${lines.join('\r\n')}\r\n';
  }

  @override
  Future<ExportOutcome> exportAllToZip(
    Database database,
    ExportValueMode mode,
    String outputPath,
  ) async {
    final exportable = database.videos
        .where((video) => !video.missing && video.annotation != null)
        .toList();
    if (exportable.isEmpty) {
      return const ExportOutcome.failure('No annotated videos to export.');
    }

    final temporary = _temporaryPath(outputPath);
    final usedNames = <String>{};
    final encoder = ZipFileEncoder();
    try {
      await File(outputPath).parent.create(recursive: true);
      encoder.create(temporary);
      for (final video in exportable) {
        final annotation = video.annotation!;
        final template = database.findTemplate(annotation.templateId);
        if (template == null) continue;
        final baseName = _zipEntryName(database.videosFolder, video.path);
        final entryName = _uniqueName(baseName, usedNames);
        encoder.addArchiveFile(
          ArchiveFile.string(
            entryName,
            buildVideoCsv(template, video.durationMs, annotation, mode),
          ),
        );
      }
      encoder.closeSync();
      _platformFiles.atomicReplace(temporary, outputPath);
      return const ExportOutcome.success();
    } on Object catch (error) {
      return ExportOutcome.failure(error.toString());
    } finally {
      final file = File(temporary);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<ExportOutcome> exportQueryCsv(
    List<String> topQueryRow,
    List<String> bottomQueryRow,
    List<CombinedQueryRow> rows,
    String outputPath,
  ) async {
    final lines = <String>[
      csvLine(topQueryRow),
      csvLine(bottomQueryRow),
      '',
      csvLine(<String>['Video', 'Num', 'Den', 'Total']),
      ...rows.map(
        (row) => csvLine(<String>[
          row.name,
          '${row.topMatched}',
          '${row.bottomMatched}',
          '${row.total}',
        ]),
      ),
    ];
    final temporary = _temporaryPath(outputPath);
    try {
      await File(outputPath).parent.create(recursive: true);
      final file = await File(temporary).open(mode: FileMode.write);
      await file.writeFrom(utf8.encode('${lines.join('\r\n')}\r\n'));
      await file.flush();
      await file.close();
      _platformFiles.atomicReplace(temporary, outputPath);
      return const ExportOutcome.success();
    } on Object catch (error) {
      return ExportOutcome.failure(error.toString());
    } finally {
      final file = File(temporary);
      if (await file.exists()) await file.delete();
    }
  }

  static String _zipEntryName(String root, String path) {
    var name = p.basename(path);
    if (root.isNotEmpty && p.isWithin(root, path)) {
      name = p.relative(path, from: root);
    }
    return '${name.replaceAll(RegExp(r'[\\/]+'), '_')}.csv';
  }

  static String _uniqueName(String requested, Set<String> used) {
    var candidate = requested;
    var suffix = 2;
    while (!used.add(candidate.toLowerCase())) {
      final extension = p.extension(requested);
      candidate = '${p.basenameWithoutExtension(requested)}-$suffix$extension';
      suffix++;
    }
    return candidate;
  }

  static String _temporaryPath(String destination) =>
      '$destination.tmp.${pid}_${Random.secure().nextInt(1 << 32)}';
}
