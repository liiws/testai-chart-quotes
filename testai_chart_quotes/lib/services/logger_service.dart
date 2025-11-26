import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  bool _initialized = false;
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final dateFormat = DateFormat('yyyy-MM-dd');
      final today = dateFormat.format(DateTime.now());
      _logFile = File('${logDir.path}/app_$today.log');

      // Rotate logs if file is too large
      await _rotateLogsIfNeeded();

      // Log initialization
      await _writeToFile(LogLevel.info, 'Application started');
      _initialized = true;
    } catch (e) {
      // If logging fails, we can't log it, so just print
      print('Failed to initialize logger: $e');
    }
  }

  Future<void> _rotateLogsIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    try {
      final fileSize = await _logFile!.length();
      if (fileSize > _maxLogFileSize) {
        final directory = _logFile!.parent;
        final dateFormat = DateFormat('yyyy-MM-dd_HHmmss');
        final timestamp = dateFormat.format(DateTime.now());
        final rotatedFile = File('${directory.path}/app_$timestamp.log');
        await _logFile!.copy(rotatedFile.path);
        await _logFile!.writeAsString(''); // Clear current log

        // Keep only the last N log files
        final logFiles = directory
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('app_') && f.path.endsWith('.log'))
            .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        if (logFiles.length > _maxLogFiles) {
          for (var file in logFiles.sublist(_maxLogFiles)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error rotating logs: $e');
    }
  }

  Future<void> debug(String message, [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.debug, message, error, stackTrace);
  }

  Future<void> info(String message, [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.info, message, error, stackTrace);
  }

  Future<void> warning(String message, [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.warning, message, error, stackTrace);
  }

  Future<void> error(String message, [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.error, message, error, stackTrace);
  }

  Future<void> _log(
    LogLevel level,
    String message,
    [Object? error, StackTrace? stackTrace]
  ) async {
    if (!_initialized) {
      await initialize();
    }

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '[$timestamp] [$levelStr] $message';

    // Print to console
    print(logMessage);
    if (error != null) {
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Write to file
    await _writeToFile(level, message, error, stackTrace);
  }

  Future<void> _writeToFile(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) async {
    if (_logFile == null) return;

    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final levelStr = level.name.toUpperCase().padRight(7);
      var logEntry = '[$timestamp] [$levelStr] $message';

      if (error != null) {
        logEntry += '\n  Error: $error';
      }

      if (stackTrace != null) {
        logEntry += '\n  Stack trace:\n${stackTrace.toString().split('\n').take(10).join('\n')}';
      }

      logEntry += '\n';

      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      // If file writing fails, we can't log it, so just print
      print('Failed to write to log file: $e');
    }
  }

  Future<String> getLogFilePath() async {
    if (!_initialized) {
      await initialize();
    }
    return _logFile?.path ?? 'Not initialized';
  }

  Future<List<String>> getRecentLogs([int lines = 100]) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return [];
    }

    try {
      final content = await _logFile!.readAsString();
      final logLines = content.split('\n');
      return logLines.length > lines
          ? logLines.sublist(logLines.length - lines)
          : logLines;
    } catch (e) {
      return ['Error reading logs: $e'];
    }
  }
}

