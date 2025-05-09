import 'dart:typed_data';

// Stub implementations of dart:io classes for web
// ignore_for_file: camel_case_types, non_constant_identifier_names

class File {
  final String path;

  File(this.path);

  // Stub methods
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Uint8List readAsBytesSync() => Uint8List(0);
  Stream<List<int>> openRead() => Stream.empty();
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
}

class Directory {
  final String path;

  Directory(this.path);

  // Stub methods
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

class FileSystemEntity {
  static Future<bool> isDirectory(String path) async => false;
  static Future<bool> isFile(String path) async => false;
}

class FileSystemException implements Exception {
  final String message;
  final String path;
  final OSError? osError;

  FileSystemException([this.message = "", this.path = "", this.osError]);

  @override
  String toString() => "FileSystemException: $message, path = '$path'";
}

class OSError {
  final String message;
  final int errorCode;

  OSError([this.message = "", this.errorCode = 0]);

  @override
  String toString() => "OSError: $message, errno = $errorCode";
}

// Add other stub classes as needed
