import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/default_template.dart';
import '../domain/interval_model.dart';
import '../domain/models.dart';
import '../localization/app_strings.dart';
import 'export_service.dart';
import 'query_service.dart';
import 'state_store.dart';
import 'video_scanner.dart';

final class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.scanner,
    required this.exportService,
    required this.queryService,
    required this.strings,
  }) : database = makeDefaultDatabase(strings);

  final StateStore store;
  final VideoScanner scanner;
  final ExportService exportService;
  final QueryService queryService;
  final AppStrings strings;

  Database database;
  bool initialized = false;
  bool scanning = false;
  int scanCompleted = 0;
  int scanTotal = 0;
  String? error;
  Timer? _saveTimer;

  Future<void> initialize() async {
    try {
      await store.acquireLock();
      database = await store.load() ?? makeDefaultDatabase(strings);
      initialized = true;
    } on Object catch (exception) {
      debugPrint('Não foi possível abrir os dados da aplicação: $exception');
      error = strings.text('error_open_data');
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> scanFolder(String directory) async {
    scanning = true;
    scanCompleted = 0;
    scanTotal = 0;
    error = null;
    database.videosFolder = directory;
    notifyListeners();
    try {
      final entries = await scanner.scan(
        directory,
        onProgress: (completed, total) {
          scanCompleted = completed;
          scanTotal = total;
          notifyListeners();
        },
      );
      _mergeScan(entries);
      _scheduleSave();
    } on Object catch (exception) {
      debugPrint('Não foi possível analisar os vídeos: $exception');
      error = strings.text('error_scan_videos');
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void _mergeScan(List<ScanEntry> entries) {
    final existing = <String, VideoRecord>{
      for (final video in database.videos) video.path: video,
    };
    final seen = <String>{};
    final merged = <VideoRecord>[];
    for (final entry in entries) {
      seen.add(entry.path);
      final old = existing[entry.path];
      if (old != null && old.md5.isNotEmpty && old.md5 == entry.md5) {
        old
          ..size = entry.size
          ..missing = false;
        merged.add(old);
      } else {
        merged.add(
          VideoRecord(
            path: entry.path,
            size: entry.size,
            md5: entry.md5,
            durationMs: entry.durationMs,
          ),
        );
      }
    }
    for (final video in existing.values) {
      if (!seen.contains(video.path)) {
        video.missing = true;
        merged.add(video);
      }
    }
    merged.sort((left, right) => left.path.compareTo(right.path));
    database.videos
      ..clear()
      ..addAll(merged);
  }

  bool videoHasAnnotations(String path) =>
      database
          .findVideo(path)
          ?.annotation
          ?.intervals
          .any((item) => item.isNotEmpty) ??
      false;

  String? applyTemplate(String videoPath, String templateId) {
    final video = database.findVideo(videoPath);
    final template = database.findTemplate(templateId);
    if (video == null || template == null) {
      return strings.text('error_video_template_not_found');
    }
    if (video.durationMs <= 0) {
      return strings.text('error_video_duration_unknown');
    }
    video.annotation = Annotation(
      templateId: templateId,
      intervalMs: template.intervalMs,
      intervals: List<Interval>.generate(
        IntervalModel.intervalCount(video.durationMs, template.intervalMs),
        (_) => <int, int>{},
      ),
    );
    _changed();
    return null;
  }

  void clearTemplate(String videoPath) {
    database.findVideo(videoPath)?.annotation = null;
    _changed();
  }

  void setIntervalValue(
    String videoPath,
    int intervalIndex,
    AttributeId attributeId,
    ValueId? valueId,
  ) {
    final annotation = database.findVideo(videoPath)?.annotation;
    if (annotation == null ||
        intervalIndex < 0 ||
        intervalIndex >= annotation.intervals.length) {
      return;
    }
    if (valueId == null) {
      annotation.intervals[intervalIndex].remove(attributeId);
    } else {
      annotation.intervals[intervalIndex][attributeId] = valueId;
    }
    _changed();
  }

  void setLastInterval(String videoPath, int index) {
    final annotation = database.findVideo(videoPath)?.annotation;
    if (annotation == null) return;
    annotation.lastInterval = IntervalModel.clampIndex(
      index,
      annotation.intervals.length,
    );
    _scheduleSave();
  }

  String addTemplate(String name, int intervalMs) {
    final template = ObservationTemplate.fromJson(
      makeDemoTemplate(strings).toJson(),
    );
    final id = _uuidV4();
    final replacement = ObservationTemplate(
      id: id,
      name: name,
      intervalMs: max(1, intervalMs),
      nextAttributeId: template.nextAttributeId,
      nextValueId: template.nextValueId,
      attributes: template.attributes,
    );
    database.templates.add(replacement);
    _changed();
    return id;
  }

  void renameTemplate(String templateId, String name) {
    final template = database.findTemplate(templateId);
    if (template == null) return;
    template.name = name;
    _changed();
  }

  void setTemplateInterval(String templateId, int intervalMs) {
    final template = database.findTemplate(templateId);
    if (template == null) return;
    template.intervalMs = max(1, intervalMs);
    _changed();
  }

  int addAttribute(String templateId, String name) {
    final template = database.findTemplate(templateId);
    if (template == null) return 0;
    final id = template.nextAttributeId++;
    template.attributes.add(ObservationAttribute(id: id, name: name));
    _changed();
    return id;
  }

  void renameAttribute(String templateId, int attributeId, String name) {
    final attribute = database
        .findTemplate(templateId)
        ?.findAttribute(attributeId);
    if (attribute == null) return;
    attribute.name = name;
    _changed();
  }

  int attributeUsageCount(String templateId, int attributeId) {
    var count = 0;
    for (final video in database.videos) {
      final annotation = video.annotation;
      if (annotation?.templateId != templateId) continue;
      count += annotation!.intervals
          .where((item) => item.containsKey(attributeId))
          .length;
    }
    return count;
  }

  void deleteAttribute(String templateId, int attributeId) {
    final template = database.findTemplate(templateId);
    if (template == null) return;
    for (final video in database.videos) {
      final annotation = video.annotation;
      if (annotation?.templateId != templateId) continue;
      for (final interval in annotation!.intervals) {
        interval.remove(attributeId);
      }
    }
    template.attributes.removeWhere((attribute) => attribute.id == attributeId);
    _changed();
  }

  int addValue(String templateId, int attributeId, String name) {
    final template = database.findTemplate(templateId);
    final attribute = template?.findAttribute(attributeId);
    if (template == null || attribute == null) return 0;
    final id = template.nextValueId++;
    attribute.values.add(ObservationValue(id: id, name: name));
    _changed();
    return id;
  }

  void renameValue(
    String templateId,
    int attributeId,
    int valueId,
    String name,
  ) {
    final value = database
        .findTemplate(templateId)
        ?.findAttribute(attributeId)
        ?.findValue(valueId);
    if (value == null) return;
    value.name = name;
    _changed();
  }

  int valueUsageCount(String templateId, int attributeId, int valueId) {
    var count = 0;
    for (final video in database.videos) {
      final annotation = video.annotation;
      if (annotation?.templateId != templateId) continue;
      count += annotation!.intervals
          .where((interval) => interval[attributeId] == valueId)
          .length;
    }
    return count;
  }

  void deleteValue(String templateId, int attributeId, int valueId) {
    final attribute = database
        .findTemplate(templateId)
        ?.findAttribute(attributeId);
    if (attribute == null) return;
    for (final video in database.videos) {
      final annotation = video.annotation;
      if (annotation?.templateId != templateId) continue;
      for (final interval in annotation!.intervals) {
        if (interval[attributeId] == valueId) interval.remove(attributeId);
      }
    }
    attribute.values.removeWhere((value) => value.id == valueId);
    _changed();
  }

  List<String> videosUsingTemplate(String templateId) => database.videos
      .where((video) => video.annotation?.templateId == templateId)
      .map((video) => video.path)
      .toList();

  bool deleteTemplate(String templateId) {
    if (videosUsingTemplate(templateId).isNotEmpty) return false;
    database.templates.removeWhere((template) => template.id == templateId);
    _changed();
    return true;
  }

  Future<void> flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final errors = await store.save(database);
    if (errors.isNotEmpty) {
      debugPrint('Não foi possível guardar: ${errors.join('; ')}');
      error = strings.text('error_save');
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(flushSave());
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(flushSave().whenComplete(store.close));
    super.dispose();
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
