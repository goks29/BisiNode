import 'dart:developer' as dev;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LogHelper {
  static Future<void> writeLog(
    String message, {
    String source = "Unknown",
    int level = 2,
  }) async {
    final int configLevel =
        int.tryParse(dotenv.env['LOG_LEVEL'] ?? '2') ?? 2;
    final String muteList = dotenv.env['LOG_MUTE'] ?? '';

    if (level > configLevel) return;
    if (muteList.split(',').contains(source)) return;

    try {
      String timestamp =
          DateFormat('HH:mm:ss').format(DateTime.now());
      String label = _getLabel(level);

      final formattedMessage =
          '[$timestamp][$label][$source] -> $message';

      dev.log(
        formattedMessage,
        name: source,
        time: DateTime.now(),
        level: level * 100,
      );
    } catch (e) {
      dev.log(
        "Logging failed: $e",
        name: "SYSTEM",
        level: 1000,
      );
    }
  }

  static String _getLabel(int level) {
    switch (level) {
      case 1:
        return "ERROR";
      case 2:
        return "INFO";
      case 3:
        return "VERBOSE";
      default:
        return "LOG";
    }
  }
}