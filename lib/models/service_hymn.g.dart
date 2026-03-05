// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_hymn.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ServiceHymnAdapter extends TypeAdapter<ServiceHymn> {
  @override
  final int typeId = 1;

  @override
  ServiceHymn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServiceHymn(
      category: fields[0] as String,
      hymn: fields[1] as Hymn,
      order: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ServiceHymn obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.category)
      ..writeByte(1)
      ..write(obj.hymn)
      ..writeByte(2)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceHymnAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
