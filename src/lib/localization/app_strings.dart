import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';

final class AppStrings {
  AppStrings._(this._values);

  final Map<String, String> _values;

  static Future<AppStrings> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      'assets/i18n/pt.yaml',
    );
    return AppStrings.fromYaml(source);
  }

  factory AppStrings.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! YamlMap) {
      throw const FormatException(
        'O ficheiro de texto tem de ser um mapa YAML.',
      );
    }
    final values = <String, String>{};
    for (final entry in document.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'Todas as chaves e valores do ficheiro de texto têm de ser texto.',
        );
      }
      values[entry.key as String] = entry.value as String;
    }
    return AppStrings._(Map<String, String>.unmodifiable(values));
  }

  String text(String key, [Map<String, Object> parameters = const {}]) {
    var value = _values[key];
    if (value == null) {
      throw StateError('Falta a chave de texto «$key».');
    }
    for (final entry in parameters.entries) {
      value = value!.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value!;
  }

  Set<String> get keys => _values.keys.toSet();
}

final class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    required this.strings,
    required super.child,
    super.key,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope não encontrado.');
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      strings != oldWidget.strings;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStringsScope.of(this);
}
