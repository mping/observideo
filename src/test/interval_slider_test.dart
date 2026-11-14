import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/ui/interval_slider.dart';

void main() {
  test('tick fractions mark each numbered section start', () {
    expect(intervalTickFractions(31000, 15000), <double>[
      0,
      15000 / 31000,
      30000 / 31000,
    ]);
    expect(intervalTickFractions(30000, 15000), <double>[0, 0.5]);
  });

  testWidgets('interval slider keeps continuous scrubbing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: IntervalSlider(
            durationMs: 31000,
            intervalMs: 15000,
            positionMs: 1000,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, isNull);
    expect(slider.max, 31000);
    expect(
      find.byKey(const ValueKey<String>('interval-slider')),
      findsOneWidget,
    );
  });
}
