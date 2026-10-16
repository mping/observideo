import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _RenameNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RenameDart = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _OpenNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _OpenDart = int Function(Pointer<Utf8>, int);
typedef _FdNative = Int32 Function(Int32);
typedef _FdDart = int Function(int);
typedef _ReplaceFileNative = Int32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  Uint32,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _ReplaceFileDart = int Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  int,
  Pointer<Void>,
  Pointer<Void>,
);
typedef _MoveFileExNative = Int32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Uint32,
);
typedef _MoveFileExDart = int Function(Pointer<Utf16>, Pointer<Utf16>, int);

abstract interface class PlatformFiles {
  void atomicReplace(String temporaryPath, String destinationPath);
}

final class NativePlatformFiles implements PlatformFiles {
  @override
  void atomicReplace(String temporaryPath, String destinationPath) {
    if (Platform.isWindows) {
      _replaceWindows(temporaryPath, destinationPath);
    } else {
      _replacePosix(temporaryPath, destinationPath);
    }
  }

  void _replacePosix(String temporaryPath, String destinationPath) {
    final libc = DynamicLibrary.process();
    final rename = libc.lookupFunction<_RenameNative, _RenameDart>('rename');
    final source = temporaryPath.toNativeUtf8();
    final destination = destinationPath.toNativeUtf8();
    try {
      if (rename(source, destination) != 0) {
        throw FileSystemException(
          'Atomic rename failed',
          destinationPath,
          const OSError('native rename call failed'),
        );
      }
    } finally {
      calloc.free(source);
      calloc.free(destination);
    }

    // Persist the renamed directory entry as well as the already-flushed file.
    final open = libc.lookupFunction<_OpenNative, _OpenDart>('open');
    final fsync = libc.lookupFunction<_FdNative, _FdDart>('fsync');
    final close = libc.lookupFunction<_FdNative, _FdDart>('close');
    final parent = File(destinationPath).parent.path.toNativeUtf8();
    try {
      final descriptor = open(parent, 0); // O_RDONLY
      if (descriptor >= 0) {
        try {
          fsync(descriptor);
        } finally {
          close(descriptor);
        }
      }
    } finally {
      calloc.free(parent);
    }
  }

  void _replaceWindows(String temporaryPath, String destinationPath) {
    const replaceWriteThrough = 0x00000001;
    const moveReplaceExisting = 0x00000001;
    const moveWriteThrough = 0x00000008;
    final kernel = DynamicLibrary.open('kernel32.dll');
    final source = temporaryPath.toNativeUtf16();
    final destination = destinationPath.toNativeUtf16();
    try {
      var ok = 0;
      if (File(destinationPath).existsSync()) {
        final replace = kernel
            .lookupFunction<_ReplaceFileNative, _ReplaceFileDart>(
              'ReplaceFileW',
            );
        ok = replace(
          destination,
          source,
          nullptr,
          replaceWriteThrough,
          nullptr,
          nullptr,
        );
      } else {
        final move = kernel.lookupFunction<_MoveFileExNative, _MoveFileExDart>(
          'MoveFileExW',
        );
        ok = move(source, destination, moveReplaceExisting | moveWriteThrough);
      }
      if (ok == 0) {
        throw FileSystemException(
          'Atomic replacement failed',
          destinationPath,
          const OSError('native replacement call failed'),
        );
      }
    } finally {
      calloc.free(source);
      calloc.free(destination);
    }
  }
}
