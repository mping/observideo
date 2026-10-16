import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class AppPaths {
  static Future<String> stateFile() async {
    final override = Platform.environment['OBSERVIDEO_DATA_DIR'];
    final directory = override == null || override.isEmpty
        ? await getApplicationSupportDirectory()
        : Directory(override);
    return p.join(directory.path, 'observideo', 'state-v1.json');
  }
}
