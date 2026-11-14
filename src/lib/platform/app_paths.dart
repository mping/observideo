import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class AppPaths {
  static Future<String> stateFile() async =>
      p.join(await _dataDirectory(), 'state-v1.json');

  static Future<String> logFile() async =>
      p.join(await _dataDirectory(), 'observideo.log');

  static Future<String> _dataDirectory() async {
    final override = Platform.environment['OBSERVIDEO_DATA_DIR'];
    final directory = override == null || override.isEmpty
        ? await getApplicationSupportDirectory()
        : Directory(override);
    return p.join(directory.path, 'observideo');
  }
}
