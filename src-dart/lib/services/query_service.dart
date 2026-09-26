import 'package:path/path.dart' as p;

import '../domain/models.dart';

typedef QuerySelection = Map<AttributeId, ValueId?>;

enum QueryAggregator { identity, byPrefix }

final class VideoTally {
  const VideoTally({required this.matched, required this.total});

  final int matched;
  final int total;
}

final class CombinedQueryRow {
  const CombinedQueryRow({
    required this.name,
    required this.topMatched,
    required this.bottomMatched,
    required this.total,
  });

  final String name;
  final int topMatched;
  final int bottomMatched;
  final int total;
}

abstract interface class QueryService {
  bool matches(Interval interval, QuerySelection selection);
  Map<String, VideoTally> runQuery(
    List<VideoRecord> videos,
    String templateId,
    QueryAggregator aggregator,
    QuerySelection selection,
  );
  List<CombinedQueryRow> combine(
    Map<String, VideoTally> top,
    Map<String, VideoTally> bottom,
  );
}

final class DartQueryService implements QueryService {
  const DartQueryService();

  @override
  bool matches(Interval interval, QuerySelection selection) {
    for (final entry in selection.entries) {
      if (entry.value != null && interval[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  String normalizePrefix(String path) {
    final basename = p.basename(path);
    return basename.substring(0, basename.length.clamp(0, 8).toInt());
  }

  @override
  Map<String, VideoTally> runQuery(
    List<VideoRecord> videos,
    String templateId,
    QueryAggregator aggregator,
    QuerySelection selection,
  ) {
    final tally = <String, VideoTally>{};
    for (final video in videos) {
      final annotation = video.annotation;
      if (video.missing ||
          annotation == null ||
          annotation.templateId != templateId) {
        continue;
      }
      final matched = annotation.intervals
          .where((interval) => matches(interval, selection))
          .length;
      if (matched == 0) continue;
      final key = aggregator == QueryAggregator.byPrefix
          ? normalizePrefix(video.path)
          : video.path;
      final previous = tally[key];
      tally[key] = VideoTally(
        matched: (previous?.matched ?? 0) + matched,
        total: (previous?.total ?? 0) + annotation.intervals.length,
      );
    }
    return tally;
  }

  @override
  List<CombinedQueryRow> combine(
    Map<String, VideoTally> top,
    Map<String, VideoTally> bottom,
  ) {
    final names = <String>{...top.keys, ...bottom.keys}.toList()..sort();
    return names.map((name) {
      final numerator = top[name];
      final denominator = bottom[name];
      return CombinedQueryRow(
        name: name,
        topMatched: numerator?.matched ?? 0,
        bottomMatched: denominator?.matched ?? 0,
        total: (numerator?.total ?? 0) > (denominator?.total ?? 0)
            ? numerator!.total
            : denominator?.total ?? 0,
      );
    }).toList();
  }
}
