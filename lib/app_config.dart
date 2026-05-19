import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._();

  static const _fallbackApiHostname = 'http://10.0.2.2:8000';
  static final Map<String, String> _values = {};

  static String get apiHostname {
    final fromEnvFile = _values['API_HOSTNAME'];
    if (fromEnvFile != null && fromEnvFile.trim().isNotEmpty) {
      return fromEnvFile.trim().replaceAll(RegExp(r'/$'), '');
    }

    return const String.fromEnvironment(
      'API_HOSTNAME',
      defaultValue: _fallbackApiHostname,
    ).replaceAll(RegExp(r'/$'), '');
  }

  static Future<void> load() async {
    try {
      final content = await rootBundle.loadString('.env');
      _values
        ..clear()
        ..addAll(_parseEnv(content));
    } on FlutterError {
      _values.clear();
    }
  }

  static Map<String, String> _parseEnv(String content) {
    final values = <String, String>{};

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      values[key] = _stripQuotes(value);
    }

    return values;
  }

  static String _stripQuotes(String value) {
    if (value.length < 2) {
      return value;
    }

    final startsAndEndsWithSingleQuote =
        value.startsWith("'") && value.endsWith("'");
    final startsAndEndsWithDoubleQuote =
        value.startsWith('"') && value.endsWith('"');
    if (startsAndEndsWithSingleQuote || startsAndEndsWithDoubleQuote) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }
}
