import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:observideo/localization/app_strings.dart';

void main() {
  final source = File('assets/i18n/pt.yaml').readAsStringSync();
  final strings = AppStrings.fromYaml(source);

  test('Portuguese YAML supports parameter interpolation', () {
    expect(
      strings.text('editor_interval_position', <String, Object>{
        'current': 2,
        'total': 5,
      }),
      'Intervalo 2 de 5',
    );
  });

  test('every localization key used by Dart exists in the YAML catalog', () {
    final referencedKeys = <String>{};
    final keyPattern = RegExp(r"strings\.text\(\s*'([^']+)'");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final dart = entity.readAsStringSync();
      referencedKeys.addAll(
        keyPattern.allMatches(dart).map((match) => match.group(1)!),
      );
    }

    expect(referencedKeys, isNotEmpty);
    expect(referencedKeys.difference(strings.keys), isEmpty);
  });

  test(
    'UI source contains no directly embedded Text, label, or tooltip copy',
    () {
      final directCopy = RegExp(
        r'''(?:const\s+)?(?:Text|SelectableText)\(\s*['"]|'''
        r'''labelText:\s*['"]|tooltip:\s*['"]''',
      );
      final violations = <String>[];
      for (final entity in Directory('lib/ui').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final dart = entity.readAsStringSync();
        if (directCopy.hasMatch(dart)) violations.add(entity.path);
      }
      expect(violations, isEmpty);
    },
  );
}
