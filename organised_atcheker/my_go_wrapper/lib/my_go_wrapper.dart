import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// FFI signatures
typedef FetchAttendanceFFIFunc = Pointer<Utf8> Function(Pointer<Utf8> username, Pointer<Utf8> password);
typedef FetchAttendanceDartFunc = Pointer<Utf8> Function(Pointer<Utf8> username, Pointer<Utf8> password);

typedef FreeStringFFIFunc = Void Function(Pointer<Utf8> s);
typedef FreeStringDartFunc = void Function(Pointer<Utf8> s);

class ScraperFFI {
  static final ScraperFFI _instance = ScraperFFI._internal();
  late DynamicLibrary _lib;
  late FetchAttendanceDartFunc _fetchAttendance;
  late FreeStringDartFunc _freeString;

  factory ScraperFFI() => _instance;

  ScraperFFI._internal() {
    _lib = _loadLibrary();
    _fetchAttendance = _lib
        .lookup<NativeFunction<FetchAttendanceFFIFunc>>('FetchAttendanceFFI')
        .asFunction();
    _freeString = _lib
        .lookup<NativeFunction<FreeStringFFIFunc>>('FreeString')
        .asFunction();
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libscraper.so');
    }
    // Add other platforms if needed
    if (Platform.isIOS) {
    // iOS looks inside its own process
    dylib = DynamicLibrary.executable(); 
}
  }

  String fetchAttendance(String username, String password) {
    final userPtr = username.toNativeUtf8();
    final passPtr = password.toNativeUtf8();

    try {
      final resultPtr = _fetchAttendance(userPtr, passPtr);
      final result = resultPtr.toDartString();
      _freeString(resultPtr);
      return result;
    } finally {
      malloc.free(userPtr);
      malloc.free(passPtr);
    }
  }
}
