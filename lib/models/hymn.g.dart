// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hymn.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HymnAdapter extends TypeAdapter<Hymn> {
  @override
  final int typeId = 0;

  @override
  Hymn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Hymn(
      id: fields[0] as int,
      hymnNumber: fields[1] as int,
      title: fields[2] as String,
      content: fields[3] as String,
      createdAt: fields[4] as String?,
      isFavorite: fields[5] as bool?,
      englishName: fields[6] as String?,
      scriptureReference: fields[7] as String?,
      audioId: fields[8] as String?,
      sectionNumber: fields[9] as int,
      hymnSuffix: fields[10] as String?,
      isFavoriteLocal: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Hymn obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.hymnNumber)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.englishName)
      ..writeByte(7)
      ..write(obj.scriptureReference)
      ..writeByte(8)
      ..write(obj.audioId)
      ..writeByte(9)
      ..write(obj.sectionNumber)
      ..writeByte(10)
      ..write(obj.hymnSuffix)
      ..writeByte(11)
      ..write(obj.isFavoriteLocal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HymnAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Hymn _$HymnFromJson(Map<String, dynamic> json) => Hymn(
      id: (json['id'] as num).toInt(),
      hymnNumber: (json['hymn_number'] as num).toInt(),
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] as String?,
      isFavorite: json['is_favorite'] as bool?,
      englishName: json['english_name'] as String?,
      scriptureReference: json['scripture_reference'] as String?,
      audioId: json['audio_id'] as String?,
      sectionNumber: (json['section_number'] as num).toInt(),
      hymnSuffix: json['hymn_suffix'] as String?,
    );

Map<String, dynamic> _$HymnToJson(Hymn instance) => <String, dynamic>{
      'id': instance.id,
      'hymn_number': instance.hymnNumber,
      'title': instance.title,
      'content': instance.content,
      'created_at': instance.createdAt,
      'is_favorite': instance.isFavorite,
      'english_name': instance.englishName,
      'scripture_reference': instance.scriptureReference,
      'audio_id': instance.audioId,
      'section_number': instance.sectionNumber,
      'hymn_suffix': instance.hymnSuffix,
    };
