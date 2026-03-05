import 'package:hive/hive.dart';
import 'hymn.dart';

part 'service_hymn.g.dart';

@HiveType(typeId: 1)
class ServiceHymn extends HiveObject {
  @HiveField(0)
  final String category; // e.g., "Opening", "Offering", "Closing"

  @HiveField(1)
  final Hymn hymn;

  @HiveField(2)
  final int order; // The order in the service

  ServiceHymn({
    required this.category,
    required this.hymn,
    required this.order,
  });

  ServiceHymn copyWith({
    String? category,
    Hymn? hymn,
    int? order,
  }) {
    return ServiceHymn(
      category: category ?? this.category,
      hymn: hymn ?? this.hymn,
      order: order ?? this.order,
    );
  }
}
