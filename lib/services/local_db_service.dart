import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hymn.dart';
import '../models/service_hymn.dart';

class LocalDbService {
  static const String hymnsBoxName = 'hymns_box';
  static const String serviceBoxName = 'service_box';
  static const String settingsBoxName = 'settings_box';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HymnAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ServiceHymnAdapter());
    }

    // Open boxes
    await Hive.openBox<Hymn>(hymnsBoxName);
    await Hive.openBox<ServiceHymn>(serviceBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);

    // Seed database if not marked offline ready
    if (!isOfflineReady()) {
      await _seedDatabase();
    }
  }

  Future<void> _seedDatabase() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/hymns.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Hymn> bundledHymns = jsonList.map((json) {
        return Hymn(
          id: json['id'] as int,
          hymnNumber: json['hymn_number'] as int,
          title: json['title'] as String,
          content: json['content'] as String,
          sectionNumber: json['section_number'] as int,
          englishName: json['english_name'] as String?,
          scriptureReference: json['scripture_reference'] as String?,
          audioId: json['audio_id'] as String?,
          hymnSuffix: json['hymn_suffix'] as String?,
        );
      }).toList();
      
      await saveHymns(bundledHymns);
    } catch (e) {
      debugPrint('Error seeding database from local JSON: $e');
    }
  }

  Box<Hymn> get hymnsBox => Hive.box<Hymn>(hymnsBoxName);
  Box<ServiceHymn> get serviceBox => Hive.box<ServiceHymn>(serviceBoxName);
  Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  // Hymns
  Future<void> saveHymns(List<Hymn> hymns) async {
    final Map<int, Hymn> hymnsMap = {for (var h in hymns) h.id: h};
    
    // Preserve local favorites
    for (var hymn in hymns) {
      final existing = hymnsBox.get(hymn.id);
      if (existing != null) {
        hymn.isFavoriteLocal = existing.isFavoriteLocal;
      }
    }
    
    await hymnsBox.putAll(hymnsMap);
    await setOfflineReady(true);
  }

  List<Hymn> getAllHymns() {
    return hymnsBox.values.toList()
      ..sort((a, b) {
        int cmp = a.sectionNumber.compareTo(b.sectionNumber);
        if (cmp != 0) return cmp;
        return a.hymnNumber.compareTo(b.hymnNumber);
      });
  }

  Future<void> clearHymns() async {
    await hymnsBox.clear();
    await setOfflineReady(false);
  }

  // Favorites
  Future<void> toggleFavorite(int id) async {
    final hymn = hymnsBox.get(id);
    if (hymn != null) {
      hymn.isFavoriteLocal = !hymn.isFavoriteLocal;
      await hymn.save(); // HiveObject save
    }
  }

  List<Hymn> getFavoriteHymns() {
    return hymnsBox.values.where((h) => h.isFavoriteLocal).toList();
  }

  // Offline Flag
  Future<void> setOfflineReady(bool ready) async {
    await settingsBox.put('offlineReady', ready);
  }

  bool isOfflineReady() {
    return settingsBox.get('offlineReady', defaultValue: false);
  }
}
