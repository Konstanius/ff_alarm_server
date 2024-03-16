import 'dart:io';

import 'package:intl/intl.dart';

enum Color {
  /// Red
  error,

  /// Orange
  warn,

  /// Green
  success,

  /// Blue
  info,

  /// Pink
  module,

  /// Gray
  verbose,

  /// Default
  white,
}

extension ColorExtension on Color {
  String get code {
    switch (this) {
      case Color.error:
        return '\x1B[31m';
      case Color.warn:
        return '\x1B[33m';
      case Color.success:
        return '\x1B[32m';
      case Color.info:
        return '\x1B[34m';
      case Color.module:
        return '\x1B[35m';
      case Color.verbose:
        return '\x1B[37m';
      case Color.white:
        return '\x1B[37m';
    }
  }

  String get name {
    switch (this) {
      case Color.error:
        return 'E';
      case Color.warn:
        return 'W';
      case Color.success:
        return 'S';
      case Color.info:
        return 'I';
      case Color.module:
        return 'M';
      case Color.verbose:
        return 'V';
      case Color.white:
        return 'D';
    }
  }

  static Color fromName(String name) {
    switch (name) {
      case 'E':
        return Color.error;
      case 'W':
        return Color.warn;
      case 'S':
        return Color.success;
      case 'I':
        return Color.info;
      case 'M':
        return Color.module;
      case 'V':
        return Color.verbose;
      case 'D':
        return Color.white;
    }
    return Color.white;
  }
}

File? logFile;

void out(String text, Color? color) {
  color ??= Color.white;
  if (text.length > 2500) {
    bool lastCharIsNewLine = text.endsWith('\n');
    text = "${text.substring(0, 1000)}...";
    if (lastCharIsNewLine) text += '\n';
  }
  stdout.write('${color.code}$text\x1B[0m');

  // Log file output
  if (logFile != null && !text.startsWith("\r\r")) {
    logFile!.writeAsStringSync(text.substring(0, text.length - 1), mode: FileMode.append);
  }
}

void outln(String text, Color? color, {bool remoteLog = true}) {
  DateTime now = DateTime.now();
  color ??= Color.white;

  text = '\r${DateFormat('yyyy.MM.dd HH:mm:ss').format(now)} [${color.name}] | $text\n';

  out(text, color);
}

void outr(String text, Color? color) {
  out("\r$text", color);
}

void outdiv(Color? color) {
  outln('--------------------------------------------------------------------------------', color);
}
