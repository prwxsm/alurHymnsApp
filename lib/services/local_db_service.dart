import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hymn.dart';
import '../models/service_hymn.dart';

/// Service responsible for managing local Hive database storage for hymns,
/// service plans, and user preferences offline.
class LocalDbService {
  static const String hymnsBoxName = 'hymns_box';
  static const String serviceBoxName = 'service_box';
  static const String settingsBoxName = 'settings_box';

  /// Bundled hymn collection version. Increment this whenever bundled hymns
  /// are updated or corrected in assets/hymns.json.
  static const int bundledHymnsVersion = 1;

  /// Setting key for tracking the installed bundled collection version.
  static const String installedHymnsVersionKey = 'installedHymnsVersion';

  /// Legacy boolean flag key for backward compatibility.
  static const String offlineReadyKey = 'offlineReady';

  /// Setting key for backing up favorite hymn IDs to protect across migration interruptions.
  static const String favoriteIdsKey = 'persisted_favorite_hymn_ids';

  /// Initializes Hive, registers binary adapters, opens boxes, and performs
  /// version-aware bundled hymn seeding/upgrades if needed.
  Future<void> init({
    String assetPath = 'assets/hymns.json',
    String? storagePath,
  }) async {
    if (storagePath != null) {
      Hive.init(storagePath);
    } else {
      await Hive.initFlutter();
    }

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

    // Check whether an initial seed or version update is required
    final int currentVersion = getInstalledHymnsVersion();
    final bool needsImport = currentVersion < bundledHymnsVersion || hymnsBox.isEmpty;

    if (needsImport) {
      debugPrint(
        'LocalDbService: importing bundled hymns (installed: $currentVersion, bundled: $bundledHymnsVersion, total: ${hymnsBox.length})',
      );
      await importBundledHymns(assetPath: assetPath);
    }
  }

  Box<Hymn> get hymnsBox => Hive.box<Hymn>(hymnsBoxName);
  Box<ServiceHymn> get serviceBox => Hive.box<ServiceHymn>(serviceBoxName);
  Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  /// Returns the currently installed bundled hymns version.
  int getInstalledHymnsVersion() {
    final dynamic val = settingsBox.get(installedHymnsVersionKey);
    if (val is int) return val;
    // Backward compatibility: if offlineReady is true but no version is recorded, treat as v0
    if (settingsBox.get(offlineReadyKey, defaultValue: false) == true) {
      return 0;
    }
    return 0;
  }

  /// Whether the database has been successfully initialized with hymns.
  bool isOfflineReady() {
    return settingsBox.get(offlineReadyKey, defaultValue: false) == true && hymnsBox.isNotEmpty;
  }

  /// Validates and imports bundled hymns safely.
  ///
  /// Requirements handled:
  /// - Complete validation before touching existing database.
  /// - Persistent preservation and synchronization of user favorites across interruptions.
  /// - In-memory pre-import snapshot rollback in case of runtime errors during writes.
  /// - Update existing hymns with corrected lyrics/metadata.
  /// - Removal of obsolete IDs if hymns were deleted.
  /// - Safe reconciliation of [ServiceHymn] references (preserving custom notes & removed hymns).
  /// - Commit version flag only after all writes succeed.
  /// - Rollback/abort on any validation failure without corrupting data.
  Future<bool> importBundledHymns({
    String assetPath = 'assets/hymns.json',
    String? rawJsonString,
    int? targetVersion,
  }) async {
    final int versionToCommit = targetVersion ?? bundledHymnsVersion;
    Map<int, Hymn>? backupHymns;

    try {
      final String jsonContent = rawJsonString ?? await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonContent);

      if (decoded is! List || decoded.isEmpty) {
        debugPrint('Validation failed: bundled JSON is empty or not a list');
        return false;
      }

      // Step 1: Pre-validate every single record before touching Hive
      final List<Hymn> validatedHymns = [];
      final Set<int> validatedIds = {};

      for (final item in decoded) {
        if (item is! Map) {
          debugPrint('Validation failed: record is not a JSON object: $item');
          return false;
        }

        final map = Map<String, dynamic>.from(item);

        final dynamic id = map['id'];
        final dynamic hymnNumber = map['hymn_number'];
        final dynamic title = map['title'];
        final dynamic content = map['content'];
        final dynamic sectionNumber = map['section_number'];

        if (id is! int ||
            hymnNumber is! int ||
            title is! String ||
            title.trim().isEmpty ||
            content is! String ||
            content.trim().isEmpty ||
            sectionNumber is! int) {
          debugPrint('Validation failed: record has invalid or missing fields: $map');
          return false;
        }

        if (validatedIds.contains(id)) {
          debugPrint('Validation failed: duplicate hymn ID detected: $id');
          return false;
        }
        validatedIds.add(id);

        validatedHymns.add(Hymn(
          id: id,
          hymnNumber: hymnNumber,
          title: title,
          content: content,
          sectionNumber: sectionNumber,
          englishName: map['english_name'] as String?,
          scriptureReference: map['scripture_reference'] as String?,
          audioId: map['audio_id'] as String?,
          hymnSuffix: map['hymn_suffix'] as String?,
          createdAt: map['created_at'] as String?,
          isFavorite: map['is_favorite'] as bool?,
        ));
      }

      // Step 2: Extract existing local favorites and sync with persistent backup
      final Set<int> existingFavoriteIds = getFavoriteHymnIds();
      if (settingsBox.isOpen && existingFavoriteIds.isNotEmpty) {
        await settingsBox.put(favoriteIdsKey, existingFavoriteIds.toList());
      }

      // Step 3: Snapshot existing hymns in memory for instant rollback if an error occurs
      if (hymnsBox.isOpen && hymnsBox.isNotEmpty) {
        backupHymns = {for (final h in hymnsBox.values) h.id: h};
      }

      // Step 4: Apply existing favorites to incoming hymns
      final Map<int, Hymn> hymnsMap = {};
      for (final hymn in validatedHymns) {
        if (existingFavoriteIds.contains(hymn.id)) {
          hymn.isFavoriteLocal = true;
        }
        hymnsMap[hymn.id] = hymn;
      }

      // Step 5: Write all validated hymns into Hive box
      await hymnsBox.putAll(hymnsMap);

      // Step 6: Clean up any obsolete hymn keys no longer in the new collection
      final Set<int> incomingIds = hymnsMap.keys.toSet();
      final List<int> obsoleteKeys = hymnsBox.keys
          .cast<int>()
          .where((k) => !incomingIds.contains(k))
          .toList();
      if (obsoleteKeys.isNotEmpty) {
        await hymnsBox.deleteAll(obsoleteKeys);
      }

      // Step 7: Reconcile serviceBox references safely
      if (serviceBox.isOpen) {
        final List<dynamic> serviceKeys = serviceBox.keys.toList();
        for (final key in serviceKeys) {
          final serviceHymn = serviceBox.get(key);
          if (serviceHymn != null) {
            final updatedHymn = hymnsMap[serviceHymn.hymn.id];
            if (updatedHymn != null) {
              await serviceBox.put(
                key,
                serviceHymn.copyWith(hymn: updatedHymn),
              );
            }
          }
        }
      }

      // Step 8: Commit version and offline status ONLY after all writes succeed
      await settingsBox.put(installedHymnsVersionKey, versionToCommit);
      await settingsBox.put(offlineReadyKey, true);

      debugPrint('LocalDbService: successfully imported ${validatedHymns.length} hymns (version: $versionToCommit)');
      return true;
    } catch (e, st) {
      debugPrint('Error during bundled hymn import: $e\n$st');
      // Rollback to pre-import snapshot if an error interrupted writing
      if (backupHymns != null && backupHymns.isNotEmpty && hymnsBox.isOpen) {
        try {
          await hymnsBox.clear();
          await hymnsBox.putAll(backupHymns);
          debugPrint('LocalDbService: successfully rolled back hymnsBox to previous snapshot');
        } catch (rollbackError) {
          debugPrint('LocalDbService: rollback failed: $rollbackError');
        }
      }
      return false;
    }
  }

  /// Returns the set of favorite hymn IDs by checking both settingsBox backup
  /// and current hymnsBox entries (for backward compatibility).
  Set<int> getFavoriteHymnIds() {
    final Set<int> favorites = {};
    if (settingsBox.isOpen) {
      final dynamic raw = settingsBox.get(favoriteIdsKey);
      if (raw is List) {
        favorites.addAll(raw.cast<int>());
      }
    }
    if (hymnsBox.isOpen) {
      for (final hymn in hymnsBox.values) {
        if (hymn.isFavoriteLocal) {
          favorites.add(hymn.id);
        }
      }
    }
    return favorites;
  }

  /// Returns all stored hymns, sorted by sectionNumber then hymnNumber.
  List<Hymn> getAllHymns() {
    return hymnsBox.values.toList()
      ..sort((a, b) {
        final int cmp = a.sectionNumber.compareTo(b.sectionNumber);
        if (cmp != 0) return cmp;
        return a.hymnNumber.compareTo(b.hymnNumber);
      });
  }

  /// Gets a specific hymn by its unique ID.
  Hymn? getHymnById(int id) {
    return hymnsBox.get(id);
  }

  /// Toggles favorite status for a hymn by its ID and synchronizes the persistent backup.
  Future<void> toggleFavorite(int id) async {
    final hymn = hymnsBox.get(id);
    if (hymn != null) {
      hymn.isFavoriteLocal = !hymn.isFavoriteLocal;
      await hymn.save();

      // Synchronize persistent backup set
      final favorites = getFavoriteHymnIds();
      if (hymn.isFavoriteLocal) {
        favorites.add(id);
      } else {
        favorites.remove(id);
      }
      if (settingsBox.isOpen) {
        await settingsBox.put(favoriteIdsKey, favorites.toList());
      }
    }
  }

  /// Returns all favorite hymns.
  List<Hymn> getFavoriteHymns() {
    return hymnsBox.values.where((h) => h.isFavoriteLocal).toList();
  }

  /// Manually clears the hymns box (used for testing or hard reset).
  Future<void> clearHymns() async {
    await hymnsBox.clear();
    await settingsBox.put(offlineReadyKey, false);
    await settingsBox.put(installedHymnsVersionKey, 0);
    await settingsBox.delete(favoriteIdsKey);
  }
}
