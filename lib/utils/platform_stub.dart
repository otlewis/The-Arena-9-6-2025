/// Stub for dart:io Platform class to allow web compilation
///
/// This file provides a stub implementation of Platform for web builds
/// where dart:io is not available.
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;

  static int get numberOfProcessors => 4; // Default for web

  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => 'unknown';
  static String get localHostname => 'localhost';

  static Map<String, String> get environment => {};
  static String get pathSeparator => '/';
  static String get executable => '';
  static String get resolvedExecutable => '';
  static Uri get script => Uri();
  static List<String> get executableArguments => [];
  static String get packageConfig => '';
  static String get version => '';
  static String get localeName => 'en_US';
}

/// Stub for dart:io ProcessResult class
class ProcessResult {
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
  final int pid;

  ProcessResult(this.exitCode, this.stdout, this.stderr, this.pid);
}

/// Stub for dart:io Process class
class Process {
  static Future<void> killPid(int pid, [dynamic signal]) async {}

  static ProcessResult runSync(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    dynamic stdoutEncoding,
    dynamic stderrEncoding,
  }) {
    // Return empty result for web
    return ProcessResult(1, '', '', 0);
  }
}
