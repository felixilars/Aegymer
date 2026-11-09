import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Global test setup, picked up automatically by `flutter test`.
///
/// Many Linux machines ship only the runtime library `libsqlite3.so.0`
/// (the unversioned `libsqlite3.so` symlink comes from the -dev package),
/// so fall back to it to let drift's in-memory databases open in tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } on ArgumentError {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  }
  await testMain();
}
