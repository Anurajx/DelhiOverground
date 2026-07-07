import 'package:flutter/services.dart';

class Env {
  static final Map<String, String> _env = {};

  static Future<void> load() async {
    try {
      final content = await rootBundle.loadString('.env');
      for (var line in content.split('\n')) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          _env[key] = value;
        }
      }
    } catch (e) {
      // Fail silently, default fallbacks will be used
    }
  }

  static String get(String key, {String defaultValue = ''}) {
    return _env[key] ?? defaultValue;
  }
}
