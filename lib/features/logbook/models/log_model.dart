import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String authorId;

  @HiveField(6)
  final String teamId;

  @HiveField(7)
  bool isSynced;

  @HiveField(8, defaultValue: false)
  final bool isPublic;

  LogModel({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.category,
    required this.authorId,
    required this.teamId,
    this.isSynced = true,
    required this.isPublic,
  });

  factory LogModel.fromMap(Map<String,dynamic> map) {
    DateTime parsedData = DateTime.now();
    if (map['date'] is DateTime) {
      parsedData = (map['date'] as DateTime).toLocal();
    } else if (map['date'] is String) {
      parsedData = DateTime.parse(map['date']).toLocal();
    }

    String? parsedId;
    if (map['_id'] != null) {
      parsedId = map['_id'] is ObjectId ? (map['_id'] as ObjectId).oid : map['_id'].toString();
    }

    return LogModel(
      id: parsedId,
      title: map['title'] ?? '',
      date: parsedData,
      description: map['description'] ?? '',
      category: map['category'] ?? 'Mechanical',
      authorId: map['authorId'] ?? 'unknown_user',
      teamId: map['teamId'] ?? 'no_team',
      isSynced: true,
      isPublic: map['isPublic'] ?? false,
    );
  }

  Map<String,dynamic> toMap() {
    return {
      '_id': id != null ? ObjectId.fromHexString(id!) : ObjectId(),
      'title' : title,
      'date' : date,
      'description' : description,
      'category' : category,
      'authorId' : authorId,
      'teamId' : teamId,
      'isPublic' : isPublic,
    };
  }
}