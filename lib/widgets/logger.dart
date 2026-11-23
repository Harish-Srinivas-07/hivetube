import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { log, warn, error, fatal, success }

class Logger {
  static const String reset = "\x1B[0m";
  static const String red = "\x1B[31m";
  static const String yellow = "\x1B[33m";
  static const String green = "\x1B[32m";
  static const String cyan = "\x1B[36m";
  static const String boldRed = "\x1B[1;31m";

  static String _formatTime() {
    return "[${DateFormat('dd-MM-yyyy hh:mm:ss a').format(DateTime.now())}]";
  }

  static String _getColor(LogLevel level) {
    switch (level) {
      case LogLevel.warn:
        return yellow;
      case LogLevel.error:
        return red;
      case LogLevel.fatal:
        return boldRed;
      case LogLevel.success:
        return green;
      case LogLevel.log:
        return cyan;
    }
  }

  static String _levelName(LogLevel level) {
    switch (level) {
      case LogLevel.warn:
        return "WARN";
      case LogLevel.error:
        return "ERROR";
      case LogLevel.fatal:
        return "FATAL";
      case LogLevel.success:
        return "SUCCESS";
      case LogLevel.log:
        return "LOG";
    }
  }

  static void _print(LogLevel level, String titleOrMsg, List<Object?> args) {
    // if ((isProduction || kReleaseMode) && level != LogLevel.error && level != LogLevel.fatal) {
    //   return;
    // }

    final levelStr = _levelName(level);

    String prefix;
    List<Object?> messageArgs;

    if (args.isEmpty) {
      prefix = "[$levelStr]";
      messageArgs = [titleOrMsg];
    } else {
      prefix = "[$levelStr] $titleOrMsg:";
      messageArgs = args;
    }

    final color = _getColor(level);

    debugPrint(
      "$color${_formatTime()} $prefix$reset ${messageArgs.join(" ")}",
      wrapWidth: 1024,
    );
  }

  static void log(String titleOrMsg, [dynamic arg]) {
    _print(LogLevel.log, titleOrMsg, arg == null ? [] : [arg]);
  }

  static void warn(String titleOrMsg, [dynamic arg]) {
    _print(LogLevel.warn, titleOrMsg, arg == null ? [] : [arg]);
  }

  static void error(String titleOrMsg, [dynamic arg]) {
    _print(LogLevel.error, titleOrMsg, arg == null ? [] : [arg]);
  }

  static void fatal(String titleOrMsg, [dynamic arg]) {
    _print(LogLevel.fatal, titleOrMsg, arg == null ? [] : [arg]);
  }

  static void success(String titleOrMsg, [dynamic arg]) {
    _print(LogLevel.success, titleOrMsg, arg == null ? [] : [arg]);
  }
}
