import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hymn.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Hymn extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  @JsonKey(name: 'hymn_number')
  final int hymnNumber;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String content;

  @HiveField(4)
  @JsonKey(name: 'created_at')
  final String? createdAt;

  @HiveField(5)
  @JsonKey(name: 'is_favorite')
  final bool? isFavorite;

  @HiveField(6)
  @JsonKey(name: 'english_name')
  final String? englishName;

  @HiveField(7)
  @JsonKey(name: 'scripture_reference')
  final String? scriptureReference;

  @HiveField(8)
  @JsonKey(name: 'audio_id')
  final String? audioId;

  @HiveField(9)
  @JsonKey(name: 'section_number')
  final int sectionNumber;

  @HiveField(10)
  @JsonKey(name: 'hymn_suffix')
  final String? hymnSuffix;

  // Local-only field
  @HiveField(11)
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isFavoriteLocal;

  Hymn({
    required this.id,
    required this.hymnNumber,
    required this.title,
    required this.content,
    this.createdAt,
    this.isFavorite,
    this.englishName,
    this.scriptureReference,
    this.audioId,
    required this.sectionNumber,
    this.hymnSuffix,
    this.isFavoriteLocal = false,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) => _$HymnFromJson(json);
  Map<String, dynamic> toJson() => _$HymnToJson(this);

  Hymn copyWith({
    int? id,
    int? hymnNumber,
    String? title,
    String? content,
    String? createdAt,
    bool? isFavorite,
    String? englishName,
    String? scriptureReference,
    String? audioId,
    int? sectionNumber,
    String? hymnSuffix,
    bool? isFavoriteLocal,
  }) {
    return Hymn(
      id: id ?? this.id,
      hymnNumber: hymnNumber ?? this.hymnNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      englishName: englishName ?? this.englishName,
      scriptureReference: scriptureReference ?? this.scriptureReference,
      audioId: audioId ?? this.audioId,
      sectionNumber: sectionNumber ?? this.sectionNumber,
      hymnSuffix: hymnSuffix ?? this.hymnSuffix,
      isFavoriteLocal: isFavoriteLocal ?? this.isFavoriteLocal,
    );
  }
}
