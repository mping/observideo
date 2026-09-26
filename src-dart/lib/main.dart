import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'platform/app_paths.dart';
import 'platform/media_runtime.dart';
import 'services/app_controller.dart';
import 'services/export_service.dart';
import 'services/media_probe.dart';
import 'services/query_service.dart';
import 'services/state_store.dart';
import 'services/video_scanner.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final mediaRuntime = MediaRuntime.resolve()..validate();
    MediaKit.ensureInitialized(libmpv: mediaRuntime.libmpvPath);
    final controller = AppController(
      store: JsonStateStore(await AppPaths.stateFile()),
      scanner: VideoScanner(FfprobeMediaProbe(mediaRuntime.ffprobePath)),
      exportService: DartExportService(),
      queryService: const DartQueryService(),
    );
    await controller.initialize();
    runApp(ObservideoApp(controller: controller));
  } on Object catch (error) {
    runApp(StartupFailureApp(message: error.toString()));
  }
}

final class ObservideoApp extends StatelessWidget {
  const ObservideoApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Observideo',
    debugShowCheckedModeBanner: false,
    theme: observideoTheme(),
    home: AppShell(controller: controller),
  );
}

ThemeData observideoTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315c8a)),
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  return base.copyWith(
    textTheme: _smallerTextTheme(base.textTheme),
    primaryTextTheme: _smallerTextTheme(base.primaryTextTheme),
  );
}

TextTheme _smallerTextTheme(TextTheme theme) => theme.copyWith(
  displayLarge: _smallerTextStyle(theme.displayLarge, 57),
  displayMedium: _smallerTextStyle(theme.displayMedium, 45),
  displaySmall: _smallerTextStyle(theme.displaySmall, 36),
  headlineLarge: _smallerTextStyle(theme.headlineLarge, 32),
  headlineMedium: _smallerTextStyle(theme.headlineMedium, 28),
  headlineSmall: _smallerTextStyle(theme.headlineSmall, 24),
  titleLarge: _smallerTextStyle(theme.titleLarge, 22),
  titleMedium: _smallerTextStyle(theme.titleMedium, 16),
  titleSmall: _smallerTextStyle(theme.titleSmall, 14),
  bodyLarge: _smallerTextStyle(theme.bodyLarge, 16),
  bodyMedium: _smallerTextStyle(theme.bodyMedium, 14),
  bodySmall: _smallerTextStyle(theme.bodySmall, 12),
  labelLarge: _smallerTextStyle(theme.labelLarge, 14),
  labelMedium: _smallerTextStyle(theme.labelMedium, 12),
  labelSmall: _smallerTextStyle(theme.labelSmall, 11),
);

TextStyle _smallerTextStyle(TextStyle? style, double defaultSize) =>
    (style ?? const TextStyle()).copyWith(
      fontSize: (style?.fontSize ?? defaultSize) * 0.88,
    );

final class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: observideoTheme(),
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Observideo could not start',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                SelectableText(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
