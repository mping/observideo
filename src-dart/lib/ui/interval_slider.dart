import 'dart:math' as math;

import 'package:flutter/material.dart';

final class IntervalSlider extends StatelessWidget {
  const IntervalSlider({
    required this.durationMs,
    required this.intervalMs,
    required this.positionMs,
    required this.onChanged,
    super.key,
  });

  final int durationMs;
  final int intervalMs;
  final int positionMs;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final maximum = math.max(1, durationMs).toDouble();
    final theme = Theme.of(context);
    return SliderTheme(
      data: theme.sliderTheme.copyWith(
        trackShape: _IntervalTickTrackShape(
          durationMs: durationMs,
          intervalMs: intervalMs,
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Slider(
        key: const ValueKey<String>('interval-slider'),
        min: 0,
        max: maximum,
        value: positionMs.toDouble().clamp(0, maximum).toDouble(),
        onChanged: onChanged,
      ),
    );
  }
}

@visibleForTesting
List<double> intervalTickFractions(int durationMs, int intervalMs) {
  if (durationMs <= 0 || intervalMs <= 0) return const <double>[];
  return <double>[
    for (
      var sectionStart = 0;
      sectionStart < durationMs;
      sectionStart += intervalMs
    )
      sectionStart / durationMs,
  ];
}

final class _IntervalTickTrackShape extends RoundedRectSliderTrackShape {
  const _IntervalTickTrackShape({
    required this.durationMs,
    required this.intervalMs,
    required this.labelStyle,
  });

  final int durationMs;
  final int intervalMs;
  final TextStyle? labelStyle;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    if (durationMs <= 0 || intervalMs <= 0) return;
    final sectionCount = ((durationMs - 1) ~/ intervalMs) + 1;
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (track.width <= 0) return;

    final effectiveLabelStyle =
        labelStyle ?? const TextStyle(fontSize: 10, color: Colors.black54);
    final widestLabel = TextPainter(
      text: TextSpan(text: '$sectionCount', style: effectiveLabelStyle),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();

    // At small interval sizes, sample labels and ticks together so section
    // numbers do not overlap or repeatedly paint the same physical pixels.
    final labelSpacing = math.max(18.0, widestLabel.width + 6);
    final maximumVisibleTicks = math.max(
      1,
      (track.width / labelSpacing).floor(),
    );
    final stride = math.max(1, (sectionCount / maximumVisibleTicks).ceil());
    final enabledActive = sliderTheme.activeTickMarkColor ?? Colors.white;
    final enabledInactive =
        sliderTheme.inactiveTickMarkColor ??
        sliderTheme.activeTrackColor ??
        Colors.blue;
    final activeColor = ColorTween(
      begin: sliderTheme.disabledActiveTickMarkColor ?? enabledActive,
      end: enabledActive,
    ).evaluate(enableAnimation)!;
    final inactiveColor = ColorTween(
      begin: sliderTheme.disabledInactiveTickMarkColor ?? enabledInactive,
      end: enabledInactive,
    ).evaluate(enableAnimation)!;
    final tickHeight = math.max(8.0, track.height + 4);
    final canvas = context.canvas;

    for (
      var sectionIndex = 0;
      sectionIndex < sectionCount;
      sectionIndex += stride
    ) {
      final fraction = (sectionIndex * intervalMs) / durationMs;
      final x = textDirection == TextDirection.ltr
          ? track.left + (track.width * fraction)
          : track.right - (track.width * fraction);
      final active = textDirection == TextDirection.ltr
          ? x <= thumbCenter.dx
          : x >= thumbCenter.dx;
      final paint = Paint()
        ..color = active ? activeColor : inactiveColor
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, track.center.dy - tickHeight / 2),
        Offset(x, track.center.dy + tickHeight / 2),
        paint,
      );

      final label = TextPainter(
        text: TextSpan(text: '${sectionIndex + 1}', style: effectiveLabelStyle),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      final labelLeft = (x - label.width / 2)
          .clamp(offset.dx, offset.dx + parentBox.size.width - label.width)
          .toDouble();
      label.paint(
        canvas,
        Offset(labelLeft, track.center.dy - tickHeight / 2 - label.height - 2),
      );
    }
  }
}
