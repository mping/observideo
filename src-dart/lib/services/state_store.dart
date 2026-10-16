import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../domain/models.dart';
import '../domain/validation.dart';
import '../platform/native_platform_files.dart';

abstract interface class StateStore {
  String get filePath;
  Future<void> acquireLock();
  Future<Database?> load();
  Future<List<String>> save(Database database);
  Future<void> close();
}

final class JsonStateStore implements StateStore {
  JsonStateStore(this.filePath, {PlatformFiles? platformFiles})
    : _platformFiles = platformFiles ?? NativePlatformFiles();

  @override
  final String filePath;
  final PlatformFiles _platformFiles;
  RandomAccessFile? _lockHandle;

  @override
  Future<void> acquireLock() async {
    if (_lockHandle != null) return;
    final lockFile = File('$filePath.lock');
    await lockFile.parent.create(recursive: true);
    final handle = await lockFile.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      _lockHandle = handle;
    } on Object {
      await handle.close();
      rethrow;
    }
  }

  @override
  Future<Database?> load() async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    final database = Database.fromJson(decoded);
    final errors = validateDatabase(database);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid state: ${errors.join('; ')}');
    }
    return database;
  }

  @override
  Future<List<String>> save(Database database) async {
    final errors = validateDatabase(database);
    if (errors.isNotEmpty) return errors;

    final destination = File(filePath);
    await destination.parent.create(recursive: true);
    final suffix = '${pid}_${Random.secure().nextInt(1 << 32)}';
    final temporary = File('$filePath.tmp.$suffix');
    RandomAccessFile? handle;
    try {
      handle = await temporary.open(mode: FileMode.write);
      final bytes = utf8.encode('${jsonEncode(database.toJson())}\n');
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      handle = null;
      _platformFiles.atomicReplace(temporary.path, destination.path);
      return const <String>[];
    } finally {
      if (handle != null) await handle.close();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> close() async {
    final handle = _lockHandle;
    _lockHandle = null;
    if (handle != null) {
      await handle.unlock();
      await handle.close();
    }
  }
}
