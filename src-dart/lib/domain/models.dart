typedef AttributeId = int;
typedef ValueId = int;
typedef Interval = Map<AttributeId, ValueId>;

int _readInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException("'$field' must be an integer");
}

String _readString(Object? value, String field) {
  if (value is String) return value;
  throw FormatException("'$field' must be a string");
}

List<Object?> _readList(Object? value, String field) {
  if (value is List<Object?>) return value;
  throw FormatException("'$field' must be an array");
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  throw FormatException("'$field' must be an object");
}

final class ObservationValue {
  ObservationValue({required this.id, required this.name});

  final ValueId id;
  String name;

  factory ObservationValue.fromJson(Object? value) {
    final json = _readMap(value, 'value');
    return ObservationValue(
      id: _readInt(json['id'], 'value.id'),
      name: _readString(json['name'], 'value.name'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}

final class ObservationAttribute {
  ObservationAttribute({
    required this.id,
    required this.name,
    List<ObservationValue>? values,
  }) : values = values ?? <ObservationValue>[];

  final AttributeId id;
  String name;
  final List<ObservationValue> values;

  ObservationValue? findValue(ValueId id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  factory ObservationAttribute.fromJson(Object? value) {
    final json = _readMap(value, 'attribute');
    return ObservationAttribute(
      id: _readInt(json['id'], 'attribute.id'),
      name: _readString(json['name'], 'attribute.name'),
      values: _readList(
        json['values'],
        'attribute.values',
      ).map(ObservationValue.fromJson).toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'values': values.map((value) => value.toJson()).toList(),
  };
}

final class ObservationTemplate {
  ObservationTemplate({
    required this.id,
    required this.name,
    required this.intervalMs,
    required this.nextAttributeId,
    required this.nextValueId,
    List<ObservationAttribute>? attributes,
  }) : attributes = attributes ?? <ObservationAttribute>[];

  final String id;
  String name;
  int intervalMs;
  AttributeId nextAttributeId;
  ValueId nextValueId;
  final List<ObservationAttribute> attributes;

  ObservationAttribute? findAttribute(AttributeId id) {
    for (final attribute in attributes) {
      if (attribute.id == id) return attribute;
    }
    return null;
  }

  factory ObservationTemplate.fromJson(Object? value) {
    final json = _readMap(value, 'template');
    return ObservationTemplate(
      id: _readString(json['id'], 'template.id'),
      name: _readString(json['name'], 'template.name'),
      intervalMs: _readInt(json['intervalMs'], 'template.intervalMs'),
      nextAttributeId: _readInt(
        json['nextAttributeId'],
        'template.nextAttributeId',
      ),
      nextValueId: _readInt(json['nextValueId'], 'template.nextValueId'),
      attributes: _readList(
        json['attributes'],
        'template.attributes',
      ).map(ObservationAttribute.fromJson).toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'intervalMs': intervalMs,
    'nextAttributeId': nextAttributeId,
    'nextValueId': nextValueId,
    'attributes': attributes.map((attribute) => attribute.toJson()).toList(),
  };
}

final class Annotation {
  Annotation({
    required this.templateId,
    required this.intervalMs,
    this.lastInterval = 0,
    List<Interval>? intervals,
  }) : intervals = intervals ?? <Interval>[];

  final String templateId;
  final int intervalMs;
  int lastInterval;
  final List<Interval> intervals;

  factory Annotation.fromJson(Object? value) {
    final json = _readMap(value, 'annotation');
    final rawIntervals = _readList(json['intervals'], 'annotation.intervals');
    return Annotation(
      templateId: _readString(json['templateId'], 'annotation.templateId'),
      intervalMs: _readInt(json['intervalMs'], 'annotation.intervalMs'),
      lastInterval: _readInt(json['lastInterval'], 'annotation.lastInterval'),
      intervals: rawIntervals.map((raw) {
        final encoded = _readMap(raw, 'annotation interval');
        return <int, int>{
          for (final entry in encoded.entries)
            int.parse(entry.key): _readInt(entry.value, 'interval value'),
        };
      }).toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'templateId': templateId,
    'intervalMs': intervalMs,
    'lastInterval': lastInterval,
    'intervals': intervals
        .map(
          (interval) => <String, Object?>{
            for (final entry in interval.entries)
              entry.key.toString(): entry.value,
          },
        )
        .toList(),
  };
}

final class VideoRecord {
  VideoRecord({
    required this.path,
    this.size = 0,
    this.md5 = '',
    this.durationMs = 0,
    this.missing = false,
    this.annotation,
  });

  final String path;
  int size;
  String md5;
  int durationMs;
  bool missing;
  Annotation? annotation;

  factory VideoRecord.fromJson(Object? value) {
    final json = _readMap(value, 'video');
    return VideoRecord(
      path: _readString(json['path'], 'video.path'),
      size: _readInt(json['size'], 'video.size'),
      md5: _readString(json['md5'], 'video.md5'),
      durationMs: _readInt(json['durationMs'], 'video.durationMs'),
      missing: json['missing'] is bool
          ? json['missing'] as bool
          : throw const FormatException("'video.missing' must be a boolean"),
      annotation: json['annotation'] == null
          ? null
          : Annotation.fromJson(json['annotation']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'size': size,
    'md5': md5,
    'durationMs': durationMs,
    'missing': missing,
    'annotation': annotation?.toJson(),
  };
}

final class Database {
  Database({
    this.schemaVersion = currentSchemaVersion,
    this.videosFolder = '',
    List<ObservationTemplate>? templates,
    List<VideoRecord>? videos,
  }) : templates = templates ?? <ObservationTemplate>[],
       videos = videos ?? <VideoRecord>[];

  static const int currentSchemaVersion = 1;

  int schemaVersion;
  String videosFolder;
  final List<ObservationTemplate> templates;
  final List<VideoRecord> videos;

  ObservationTemplate? findTemplate(String id) {
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  VideoRecord? findVideo(String path) {
    for (final video in videos) {
      if (video.path == path) return video;
    }
    return null;
  }

  factory Database.fromJson(Object? value) {
    final json = _readMap(value, 'database');
    final database = Database(
      schemaVersion: _readInt(json['schemaVersion'], 'schemaVersion'),
      videosFolder: _readString(json['videosFolder'], 'videosFolder'),
      templates: _readList(
        json['templates'],
        'templates',
      ).map(ObservationTemplate.fromJson).toList(),
      videos: _readList(
        json['videos'],
        'videos',
      ).map(VideoRecord.fromJson).toList(),
    );
    return database;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'videosFolder': videosFolder,
    'templates': templates.map((template) => template.toJson()).toList(),
    'videos': videos.map((video) => video.toJson()).toList(),
  };
}
