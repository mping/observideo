import 'interval_model.dart';
import 'models.dart';

List<String> validateDatabase(Database database) {
  final errors = <String>[];
  if (database.schemaVersion != Database.currentSchemaVersion) {
    errors.add(
      'unsupported schemaVersion ${database.schemaVersion} '
      '(expected ${Database.currentSchemaVersion})',
    );
  }

  final templateIds = <String>{};
  for (final template in database.templates) {
    final context = "template '${template.id}'";
    if (template.id.isEmpty) {
      errors.add('a template has an empty id');
      continue;
    }
    if (!templateIds.add(template.id)) {
      errors.add("duplicate template id '${template.id}'");
    }
    if (template.intervalMs <= 0) {
      errors.add('$context: intervalMs must be positive');
    }
    final attributeIds = <int>{};
    var maxAttributeId = 0;
    final allValueIds = <int>{};
    var maxValueId = 0;
    for (final attribute in template.attributes) {
      if (attribute.id <= 0 || !attributeIds.add(attribute.id)) {
        errors.add(
          '$context: duplicate or invalid attribute id ${attribute.id}',
        );
      }
      if (attribute.id > maxAttributeId) maxAttributeId = attribute.id;
      for (final value in attribute.values) {
        if (value.id <= 0 || !allValueIds.add(value.id)) {
          errors.add('$context: duplicate or invalid value id ${value.id}');
        }
        if (value.id > maxValueId) maxValueId = value.id;
      }
    }
    if (template.nextAttributeId <= maxAttributeId) {
      errors.add('$context: nextAttributeId must exceed every attribute id');
    }
    if (template.nextValueId <= maxValueId) {
      errors.add('$context: nextValueId must exceed every value id');
    }
  }

  final videoPaths = <String>{};
  for (final video in database.videos) {
    if (video.path.isEmpty) {
      errors.add('a video has an empty path');
    } else if (!videoPaths.add(video.path)) {
      errors.add("duplicate video path '${video.path}'");
    }
    final annotation = video.annotation;
    if (annotation == null) continue;
    final context = "video '${video.path}'";
    final template = database.findTemplate(annotation.templateId);
    if (template == null) {
      errors.add(
        "$context: annotation refers to unknown template '${annotation.templateId}'",
      );
      continue;
    }
    if (annotation.intervalMs <= 0) {
      errors.add('$context: annotation.intervalMs must be positive');
      continue;
    }
    if (video.durationMs <= 0) {
      errors.add('$context: has an annotation but no known duration');
      continue;
    }
    final expected = IntervalModel.intervalCount(
      video.durationMs,
      annotation.intervalMs,
    );
    if (annotation.intervals.length != expected) {
      errors.add(
        '$context: expected $expected intervals, found '
        '${annotation.intervals.length}',
      );
    }
    if (annotation.lastInterval < 0 ||
        annotation.lastInterval >= annotation.intervals.length) {
      errors.add('$context: lastInterval is out of range');
    }
    for (var index = 0; index < annotation.intervals.length; index++) {
      for (final entry in annotation.intervals[index].entries) {
        final attribute = template.findAttribute(entry.key);
        if (attribute == null) {
          errors.add(
            '$context: interval $index references unknown attribute id ${entry.key}',
          );
        } else if (attribute.findValue(entry.value) == null) {
          errors.add(
            "$context: interval $index, attribute '${attribute.name}': "
            'unknown value id ${entry.value}',
          );
        }
      }
    }
  }
  return errors;
}
