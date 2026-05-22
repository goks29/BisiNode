// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranslationLogAdapter extends TypeAdapter<TranslationLog> {
  @override
  final int typeId = 2;

  @override
  TranslationLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranslationLog(
      text: fields[0] as String,
      timestamp: fields[1] as DateTime,
      modelType: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TranslationLog obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.modelType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
