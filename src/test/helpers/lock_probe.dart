import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: lock_probe.dart <lock-file>');
    exitCode = 64;
    return;
  }

  final handle = await File(arguments.single).open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.exclusive);
    await handle.unlock();
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 73;
  } finally {
    await handle.close();
  }
}
