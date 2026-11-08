import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hymn.dart';
import '../models/service_hymn.dart';

/// Exception thrown when the local hymn database encounters an unrecoverable
/// initialization or migration error.
class HymnDatabaseException implements Exception {
  final String message;
  final dynamic cause;

  const HymnDatabaseException(this.message, [this.cause]);

  @override
  String toString() => 'HymnDatabaseException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Service responsible for managing local Hive database storage for hymns,
/// service plans, and user preferences offline.
class LocalDbService {
  static const String hymnsBoxName = 'hymns_box';
  static const String serviceBoxName = 'service_box';
  static const String settingsBoxName = 'settings_box';
  static const String stagingHymnsBoxName = 'staging_hymns_box';
  static const String serviceBackupBoxName = 'service_backup_box';

  /// Bundled hymn collection version. Increment this whenever bundled hymns
  /// are updated or corrected in assets/hymns.json.
  static const int bundledHymnsVersion = 1;

  /// Setting key for tracking the installed bundled collection version.
  static const String installedHymnsVersionKey = 'installedHymnsVersion';

  /// Legacy boolean flag key for backward compatibility.
  static const String offlineReadyKey = 'offlineReady';

  /// Setting key for backing up favorite hymn IDs to protect across migration interruptions.
  static const String favoriteIdsKey = 'persisted_favorite_hymn_ids';

  /// Setting key for tracking the staged migration journal on disk.
  static const String migrationJournalKey = 'migration_journal';

  /// Error message recorded if database initialization or initial seeding fails.
  String? initializationError;

  /// Initializes Hive, registers binary adapters, opens boxes, restores any
  /// interrupted migrations, and performs version-aware bundled hymn seeding/upgrades.
  ///
  /// Throws [HymnDatabaseException] if the initial import on a fresh installation fails.
  Future<void> init({
    String assetPath = 'assets/hymns.json',
    String? storagePath,
  }) async {
    initializationError = null;

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

    // Open primary boxes
    await Hive.openBox<Hymn>(hymnsBoxName);
    await Hive.openBox<ServiceHymn>(serviceBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);

    // Check if an uncompleted migration was interrupted (e.g. process was killed)
    await _recoverInterruptedMigrationIfNeeded();

    // Check whether an initial seed or version update is required
    final int currentVersion = getInstalledHymnsVersion();
    final bool needsImport = currentVersion < bundledHymnsVersion || hymnsBox.isEmpty;

    if (needsImport) {
      debugPrint(
        'LocalDbService: importing bundled hymns (installed: $currentVersion, bundled: $bundledHymnsVersion, total: ${hymnsBox.length})',
      );
      final success = await importBundledHymns(assetPath: assetPath);
      if (!success && hymnsBox.isEmpty) {
        initializationError =
            'Failed to initialize hymn collection from bundled assets. The database is empty.';
        throw HymnDatabaseException(initializationError!);
      }
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

  /// Recovers an interrupted database migration if the app was killed or crashed
  /// during a previous update.
  Future<void> _recoverInterruptedMigrationIfNeeded() async {
    if (!settingsBox.isOpen) return;

    final dynamic journalRaw = settingsBox.get(migrationJournalKey);
    if (journalRaw == null) return;

    debugPrint('LocalDbService: Incomplete migration journal detected: $journalRaw. Recovering...');

    try {
      final Map<String, dynamic> journal = Map<String, dynamic>.from(journalRaw as Map);
      final String stage = journal['stage'] as String? ?? '';
      final int targetVersion = (journal['targetVersion'] as int?) ?? bundledHymnsVersion;

      final serviceBackupBox = await Hive.openBox<ServiceHymn>(serviceBackupBoxName);
      final stagingBox = await Hive.openBox<Hymn>(stagingHymnsBoxName);

      // 1. If service backup box exists, restore all user service plans to protect against partial updates
      if (serviceBackupBox.isNotEmpty) {
        debugPrint('LocalDbService: Restoring ${serviceBackupBox.length} service plans from persistent backup...');
        await serviceBox.clear();
        for (final key in serviceBackupBox.keys) {
          final item = serviceBackupBox.get(key);
          if (item != null) {
            await serviceBox.put(key, item.copyWith(hymn: item.hymn.copyWith()));
          }
        }
      }

      // 2. If staging was completed before termination, finalize the swap into hymnsBox
      if (stagingBox.isNotEmpty && (stage == 'staged' || stage == 'committing')) {
        debugPrint('LocalDbService: Finalizing staged migration from staging box (${stagingBox.length} hymns)...');
        final Map<int, Hymn> stagedHymns = {for (final h in stagingBox.values) h.id: h.copyWith()};
        await hymnsBox.putAll(stagedHymns);

        final Set<int> incomingIds = stagedHymns.keys.toSet();
        final List<int> obsoleteKeys = hymnsBox.keys
            .cast<int>()
            .where((k) => !incomingIds.contains(k))
            .toList();
        if (obsoleteKeys.isNotEmpty) {
          await hymnsBox.deleteAll(obsoleteKeys);
        }

        // Reconcile service plans with fresh hymn data
        await _reconcileServicePlans(stagedHymns);

        // Commit version
        await settingsBox.put(installedHymnsVersionKey, targetVersion);
        await settingsBox.put(offlineReadyKey, true);
        debugPrint('LocalDbService: Interrupted migration successfully recovered and committed!');
      } else {
        debugPrint('LocalDbService: Staging was incomplete when terminated. Discarded partial staging.');
      }

      // Clean up staging, backup box, and journal
      await serviceBackupBox.clear();
      await stagingBox.clear();
      await settingsBox.delete(migrationJournalKey);
    } catch (e, st) {
      debugPrint('LocalDbService: Error during interrupted migration recovery: $e\n$st');
      // Ensure journal is cleared to avoid infinite recovery loops
      await settingsBox.delete(migrationJournalKey);
    }
  }

  /// Safely reconciles [ServiceHymn] references with incoming hymn data.
  ///
  /// Guarantees:
  /// - User-assigned service categories, notes, and ordering are preserved.
  /// - Updated lyrics and titles are propagated to service plans.
  /// - Hymns removed from future collections are preserved in service plans
  ///   so existing church services do not lose references or crash.
  Future<void> _reconcileServicePlans(Map<int, Hymn> hymnsMap) async {
    if (!serviceBox.isOpen) return;

    final List<dynamic> serviceKeys = serviceBox.keys.toList();
    for (final key in serviceKeys) {
      final serviceHymn = serviceBox.get(key);
      if (serviceHymn != null) {
        final updatedHymn = hymnsMap[serviceHymn.hymn.id];
        if (updatedHymn != null) {
          await serviceBox.put(
            key,
            serviceHymn.copyWith(hymn: updatedHymn.copyWith()),
          );
        }
      }
    }
  }

  /// Validates and imports bundled hymns safely.
  ///
  /// Requirements handled:
  /// - Complete pre-validation of all records before touching any live boxes.
  /// - Staged migration pattern: writes incoming hymns into [stagingHymnsBoxName] first.
  /// - Persistent service plans backup to [serviceBackupBoxName] before modification.
  /// - Persistent favorites synchronization via [favoriteIdsKey] in [settingsBox].
  /// - In-memory snapshot rollback for both [hymnsBox] and [serviceBox] if a runtime error occurs.
  /// - Persistent recovery journal in [settingsBox] if process is killed mid-migration.
  /// - Safe [ServiceHymn] reconciliation preserving user notes and deleted hymns.
  /// - Commits version flag only after all writes succeed.
  Future<bool> importBundledHymns({
    String assetPath = 'assets/hymns.json',
    String? rawJsonString,
    int? targetVersion,
  }) async {
    final int versionToCommit = targetVersion ?? bundledHymnsVersion;
    Map<int, Hymn>? inMemoryHymnsBackup;
    Map<dynamic, ServiceHymn>? inMemoryServiceBackup;
    Box<Hymn>? stagingBox;
    Box<ServiceHymn>? serviceBackupBox;

    try {
      final String jsonContent = rawJsonString ?? await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(jsonContent);

      if (decoded is! List || decoded.isEmpty) {
        debugPrint('Validation failed: bundled JSON is empty or not a list');
        return false;
      }

      // Step 1: Pre-validate every single record before touching any database state
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

      // Step 2: Extract existing local favorites and sync with persistent backup in settingsBox
      final Set<int> existingFavoriteIds = getFavoriteHymnIds();
      if (settingsBox.isOpen && existingFavoriteIds.isNotEmpty) {
        await settingsBox.put(favoriteIdsKey, existingFavoriteIds.toList());
      }

      // Step 3: Capture in-memory snapshots of live boxes for instant runtime rollback
      if (hymnsBox.isOpen && hymnsBox.isNotEmpty) {
        inMemoryHymnsBackup = {for (final h in hymnsBox.values) h.id: h};
      }
      if (serviceBox.isOpen && serviceBox.isNotEmpty) {
        inMemoryServiceBackup = {
          for (final key in serviceBox.keys)
            if (serviceBox.get(key) != null) key: serviceBox.get(key)!
        };
      }

      // Step 4: Write validated hymns to STAGING box on disk (live boxes remain untouched)
      stagingBox = await Hive.openBox<Hymn>(stagingHymnsBoxName);
      await stagingBox.clear();

      final Map<int, Hymn> hymnsMap = {};
      for (final hymn in validatedHymns) {
        if (existingFavoriteIds.contains(hymn.id)) {
          hymn.isFavoriteLocal = true;
        }
        hymnsMap[hymn.id] = hymn;
      }
      final Map<int, Hymn> stagedMap = {
        for (final h in hymnsMap.values) h.id: h.copyWith()
      };
      await stagingBox.putAll(stagedMap);

      // Step 5: Persist service plans to persistent backup box & record migration journal on disk
      serviceBackupBox = await Hive.openBox<ServiceHymn>(serviceBackupBoxName);
      await serviceBackupBox.clear();
      if (inMemoryServiceBackup != null && inMemoryServiceBackup.isNotEmpty) {
        for (final entry in inMemoryServiceBackup.entries) {
          await serviceBackupBox.put(
            entry.key,
            entry.value.copyWith(hymn: entry.value.hymn.copyWith()),
          );
        }
      }

      if (settingsBox.isOpen) {
        await settingsBox.put(migrationJournalKey, {
          'stage': 'staged',
          'targetVersion': versionToCommit,
        });
      }

      // Step 6: Atomic swap from staging to live hymnsBox
      final Map<int, Hymn> liveMap = {
        for (final h in hymnsMap.values) h.id: h.copyWith()
      };
      await hymnsBox.putAll(liveMap);

      final Set<int> incomingIds = liveMap.keys.toSet();
      final List<int> obsoleteKeys = hymnsBox.keys
          .cast<int>()
          .where((k) => !incomingIds.contains(k))
          .toList();
      if (obsoleteKeys.isNotEmpty) {
        await hymnsBox.deleteAll(obsoleteKeys);
      }

      // Step 7: Reconcile serviceBox references safely
      if (serviceBox.isOpen) {
        await _reconcileServicePlans(liveMap);
      }

      // Step 8: Commit version and offline status ONLY after all writes succeed
      await settingsBox.put(installedHymnsVersionKey, versionToCommit);
      await settingsBox.put(offlineReadyKey, true);

      // Clean up migration staging, persistent backup, and journal
      await settingsBox.delete(migrationJournalKey);
      await stagingBox.clear();
      await serviceBackupBox.clear();

      debugPrint('LocalDbService: successfully imported ${validatedHymns.length} hymns (version: $versionToCommit)');
      return true;
    } catch (e, st) {
      debugPrint('Error during bundled hymn import: $e\n$st');

      // Runtime rollback: restore live hymnsBox if modified
      if (inMemoryHymnsBackup != null && inMemoryHymnsBackup.isNotEmpty && hymnsBox.isOpen) {
        try {
          await hymnsBox.clear();
          await hymnsBox.putAll({
            for (final h in inMemoryHymnsBackup.values) h.id: h.copyWith()
          });
          debugPrint('LocalDbService: successfully rolled back hymnsBox to previous snapshot');
        } catch (rollbackError) {
          debugPrint('LocalDbService: hymnsBox rollback error: $rollbackError');
        }
      }

      // Runtime rollback: restore live serviceBox if modified
      if (inMemoryServiceBackup != null && inMemoryServiceBackup.isNotEmpty && serviceBox.isOpen) {
        try {
          await serviceBox.clear();
          for (final entry in inMemoryServiceBackup.entries) {
            await serviceBox.put(
              entry.key,
              entry.value.copyWith(hymn: entry.value.hymn.copyWith()),
            );
          }
          debugPrint('LocalDbService: successfully rolled back serviceBox to previous snapshot');
        } catch (rollbackError) {
          debugPrint('LocalDbService: serviceBox rollback error: $rollbackError');
        }
      }

      // Clean up journal & staging if they were opened
      try {
        if (settingsBox.isOpen) {
          await settingsBox.delete(migrationJournalKey);
        }
        if (stagingBox != null && stagingBox.isOpen) {
          await stagingBox.clear();
        }
        if (serviceBackupBox != null && serviceBackupBox.isOpen) {
          await serviceBackupBox.clear();
        }
      } catch (_) {}

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
    await settingsBox.delete(migrationJournalKey);
  }
}
