import 'dart:math' as math;

abstract final class IntervalModel {
  static int intervalCount(int durationMs, int intervalMs) {
    if (durationMs <= 0 || intervalMs <= 0) return 1;
    return math.max(1, (durationMs + intervalMs - 1) ~/ intervalMs);
  }

  static int startMs(int index, int intervalMs) => index * intervalMs;

  static int endMs(int index, int durationMs, int intervalMs) =>
      math.min((index + 1) * intervalMs, durationMs);

  static int clampIndex(int index, int count) =>
      index.clamp(0, math.max(0, count - 1)).toInt();

  static int indexForScrub(int requestedMs, int intervalMs, int count) {
    if (intervalMs <= 0) return 0;
    return clampIndex(math.max(0, requestedMs) ~/ intervalMs, count);
  }

  static bool reachedEnd(
    int positionMs,
    int selected,
    int durationMs,
    int intervalMs,
  ) => positionMs >= endMs(selected, durationMs, intervalMs);
}
