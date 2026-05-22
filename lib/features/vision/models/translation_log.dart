import 'package:hive/hive.dart';

part 'translation_log.g.dart';

@HiveType(typeId: 2)
class TranslationLog extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String modelType;

  TranslationLog({
    required this.text,
    required this.timestamp,
    required this.modelType,
  });
}
