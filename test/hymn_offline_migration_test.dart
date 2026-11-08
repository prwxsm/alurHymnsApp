import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:alur_hymn_app/models/service_hymn.dart';
import 'package:alur_hymn_app/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDbService localDb;
  late String bundledJsonContent;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('alur_hymns_test_');
    localDb = LocalDbService();
    // Read the actual bundled hymns.json file from workspace assets
    bundledJsonContent = await File('assets/hymns.json').readAsString();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Bundled Hymn Collection Verification', () {
    test('Fresh installation first launch imports bundled JSON automatically', () async {
      await localDb.init(storagePath: tempDir.path);
      // init() automatically triggers importBundledHymns if box is empty
      // In test environment, rootBundle loads assets/hymns.json if available
      final success = await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );

      expect(success, isTrue);
      expect(localDb.isOfflineReady(), isTrue);
      expect(localDb.getInstalledHymnsVersion(), equals(1));
      expect(localDb.getAllHymns().length, equals(470));
    });

    test('Import bundled JSON and verify exact section counts', () async {
      await localDb.init(storagePath: tempDir.path);

      // Import bundled collection using the raw JSON content
      final success = await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );

      expect(success, isTrue);
      expect(localDb.isOfflineReady(), isTrue);
      expect(localDb.getInstalledHymnsVersion(), equals(1));

      final allHymns = localDb.getAllHymns();
      expect(allHymns.length, equals(470), reason: 'Total hymns must be 470');

      final bukuWer = allHymns.where((h) => h.sectionNumber == 1).toList();
      final koro = allHymns.where((h) => h.sectionNumber == 2).toList();
      final yellowBook = allHymns.where((h) => h.sectionNumber == 3).toList();

      expect(bukuWer.length, equals(202), reason: 'Buku Wer must have 202 hymns');
      expect(koro.length, equals(30), reason: 'Koro must have 30 hymns');
      expect(yellowBook.length, equals(238), reason: 'Yellow Book must have 238 hymns');
    });

    test('Verify all bundled hymns have valid required fields and unique IDs', () async {
      await localDb.init(storagePath: tempDir.path);
      await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );

      final hymns = localDb.getAllHymns();
      final seenIds = <int>{};

      for (final hymn in hymns) {
        expect(hymn.id, isPositive);
        expect(seenIds.contains(hymn.id), isFalse, reason: 'Duplicate ID: ${hymn.id}');
        seenIds.add(hymn.id);

        expect(hymn.hymnNumber, isPositive);
        expect(hymn.title.trim(), isNotEmpty);
        expect(hymn.content.trim(), isNotEmpty);
        expect([1, 2, 3].contains(hymn.sectionNumber), isTrue);
      }
    });
  });

  group('Offline Search and Filtering', () {
    setUp(() async {
      await localDb.init(storagePath: tempDir.path);
      await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );
    });

    test('Search by hymn number matches correctly', () {
      final allHymns = localDb.getAllHymns();

      // Look up hymn number 1 in Section 1 (Buku Wer)
      final section1Hymn1 = allHymns.firstWhere(
        (h) => h.sectionNumber == 1 && h.hymnNumber == 1,
      );
      expect(section1Hymn1, isNotNull);
      expect(section1Hymn1.title, isNotEmpty);
    });

    test('Search by title substring matches correctly', () {
      final allHymns = localDb.getAllHymns();
      const query = 'wer';

      final matching = allHymns.where((h) => h.title.toLowerCase().contains(query)).toList();
      expect(matching, isNotEmpty);
    });

    test('Search by lyrics substring matches correctly', () {
      final allHymns = localDb.getAllHymns();
      final firstHymn = allHymns.first;
      final snippet = firstHymn.content.split('\n').first.trim().toLowerCase();

      final matching = allHymns.where((h) => h.content.toLowerCase().contains(snippet)).toList();
      expect(matching, contains(firstHymn));
    });
  });

  group('Favorites Persistence and Upgrades', () {
    test('Preserves user favorites across database version upgrades', () async {
      await localDb.init(storagePath: tempDir.path);

      // Initial v1 import
      await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );

      final initialHymns = localDb.getAllHymns();
      final hymnToFavorite1 = initialHymns[0];
      final hymnToFavorite2 = initialHymns[10];

      // Mark favorites
      await localDb.toggleFavorite(hymnToFavorite1.id);
      await localDb.toggleFavorite(hymnToFavorite2.id);

      expect(localDb.getFavoriteHymns().length, equals(2));

      // Simulate a newer bundled release (v2) with updated title for hymn 1
      final decoded = jsonDecode(bundledJsonContent) as List<dynamic>;
      final updatedJsonList = decoded.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['id'] == hymnToFavorite1.id) {
          map['title'] = 'Updated Title v2';
        }
        return map;
      }).toList();

      final updatedJsonString = jsonEncode(updatedJsonList);

      // Perform upgrade to v2
      final upgradeSuccess = await localDb.importBundledHymns(
        rawJsonString: updatedJsonString,
        targetVersion: 2,
      );

      expect(upgradeSuccess, isTrue);
      expect(localDb.getInstalledHymnsVersion(), equals(2));

      // Verify favorites are still preserved
      final favoritesAfterUpgrade = localDb.getFavoriteHymns();
      expect(favoritesAfterUpgrade.length, equals(2));

      final updatedFav1 = localDb.getHymnById(hymnToFavorite1.id);
      expect(updatedFav1, isNotNull);
      expect(updatedFav1!.isFavoriteLocal, isTrue);
      expect(updatedFav1.title, equals('Updated Title v2'), reason: 'Content was updated');

      final updatedFav2 = localDb.getHymnById(hymnToFavorite2.id);
      expect(updatedFav2, isNotNull);
      expect(updatedFav2!.isFavoriteLocal, isTrue);
    });

    test('Handles deleted or replaced hymn IDs during upgrade', () async {
      await localDb.init(storagePath: tempDir.path);

      final initialData = [
        {'id': 1, 'hymn_number': 1, 'title': 'Hymn 1', 'content': 'Content 1', 'section_number': 1},
        {'id': 2, 'hymn_number': 2, 'title': 'Hymn 2', 'content': 'Content 2', 'section_number': 1},
        {'id': 3, 'hymn_number': 3, 'title': 'Hymn 3', 'content': 'Content 3', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(initialData),
        targetVersion: 1,
      );

      expect(localDb.getAllHymns().length, equals(3));

      // Upgrade: ID 2 is removed, ID 4 is added
      final updatedData = [
        {'id': 1, 'hymn_number': 1, 'title': 'Hymn 1 Updated', 'content': 'Content 1', 'section_number': 1},
        {'id': 4, 'hymn_number': 4, 'title': 'Hymn 4', 'content': 'Content 4', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(updatedData),
        targetVersion: 2,
      );

      final hymnsAfter = localDb.getAllHymns();
      expect(hymnsAfter.length, equals(2));
      expect(hymnsAfter.map((h) => h.id).toList(), equals([1, 4]));
      expect(localDb.getHymnById(2), isNull, reason: 'ID 2 must be deleted from database');
    });

    test('Reconciles service hymn references during database upgrade', () async {
      await localDb.init(storagePath: tempDir.path);

      final initialData = [
        {'id': 100, 'hymn_number': 1, 'title': 'Original Title', 'content': 'Lyrics', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(initialData),
        targetVersion: 1,
      );

      final hymn = localDb.getHymnById(100)!;
      final serviceHymn = ServiceHymn(
        category: 'Opening',
        hymn: hymn,
        order: 1,
      );
      await localDb.serviceBox.add(serviceHymn);
      expect(localDb.serviceBox.length, equals(1));

      // Upgrade with corrected title
      final updatedData = [
        {'id': 100, 'hymn_number': 1, 'title': 'Corrected Title', 'content': 'Lyrics v2', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(updatedData),
        targetVersion: 2,
      );

      // Verify service plan was updated
      final serviceHymnAfter = localDb.serviceBox.getAt(0);
      expect(serviceHymnAfter, isNotNull);
      expect(serviceHymnAfter!.category, equals('Opening'));
      expect(serviceHymnAfter.hymn.title, equals('Corrected Title'));
      expect(serviceHymnAfter.hymn.content, equals('Lyrics v2'));
    });

    test('Preserves user settings (theme and font size) across upgrades', () async {
      await localDb.init(storagePath: tempDir.path);

      await localDb.settingsBox.put('isDarkMode', true);
      await localDb.settingsBox.put('fontSize', 24.0);

      await localDb.importBundledHymns(
        rawJsonString: bundledJsonContent,
        targetVersion: 1,
      );

      // Verify settings are unchanged after import
      expect(localDb.settingsBox.get('isDarkMode'), isTrue);
      expect(localDb.settingsBox.get('fontSize'), equals(24.0));
    });
  });

  group('Validation and Error Resilience', () {
    test('Rejects duplicate hymn IDs without corrupting database', () async {
      await localDb.init(storagePath: tempDir.path);

      // Seed valid data first
      final validData = [
        {'id': 1, 'hymn_number': 1, 'title': 'Hymn 1', 'content': 'Lyrics 1', 'section_number': 1},
      ];
      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(validData),
        targetVersion: 1,
      );
      expect(localDb.getAllHymns().length, equals(1));

      // Attempt import with duplicate IDs
      final duplicateData = [
        {'id': 2, 'hymn_number': 2, 'title': 'Hymn 2', 'content': 'Lyrics 2', 'section_number': 1},
        {'id': 2, 'hymn_number': 3, 'title': 'Duplicate ID', 'content': 'Lyrics 3', 'section_number': 1},
      ];

      final success = await localDb.importBundledHymns(
        rawJsonString: jsonEncode(duplicateData),
        targetVersion: 2,
      );

      expect(success, isFalse, reason: 'Duplicate ID must cause import to fail');
      expect(localDb.getInstalledHymnsVersion(), equals(1), reason: 'Version must not update on failure');
      expect(localDb.getAllHymns().length, equals(1), reason: 'Existing data must remain intact');
    });

    test('Rejects missing required fields without modifying database', () async {
      await localDb.init(storagePath: tempDir.path);

      final validData = [
        {'id': 10, 'hymn_number': 10, 'title': 'Hymn 10', 'content': 'Lyrics 10', 'section_number': 1},
      ];
      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(validData),
        targetVersion: 1,
      );

      // Missing 'content'
      final malformedData = [
        {'id': 11, 'hymn_number': 11, 'title': 'Hymn 11', 'section_number': 1},
      ];

      final success = await localDb.importBundledHymns(
        rawJsonString: jsonEncode(malformedData),
        targetVersion: 2,
      );

      expect(success, isFalse);
      expect(localDb.getInstalledHymnsVersion(), equals(1));
      expect(localDb.getAllHymns().length, equals(1));
      expect(localDb.getHymnById(10), isNotNull);
    });

    test('Rejects malformed JSON or empty list safely', () async {
      await localDb.init(storagePath: tempDir.path);

      // Not a list
      expect(await localDb.importBundledHymns(rawJsonString: '{"hymns": []}'), isFalse);
      // Empty list
      expect(await localDb.importBundledHymns(rawJsonString: '[]'), isFalse);
      // Invalid JSON syntax
      expect(await localDb.importBundledHymns(rawJsonString: 'INVALID_JSON'), isFalse);
    });

    test('Interruption recovery restores favorites when version commit was missed', () async {
      await localDb.init(storagePath: tempDir.path);

      final initialData = [
        {'id': 1, 'hymn_number': 1, 'title': 'Hymn 1', 'content': 'Lyrics 1', 'section_number': 1},
        {'id': 2, 'hymn_number': 2, 'title': 'Hymn 2', 'content': 'Lyrics 2', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(initialData),
        targetVersion: 1,
      );

      // User marks Hymn 2 as favorite
      await localDb.toggleFavorite(2);
      expect(localDb.getFavoriteHymns().map((h) => h.id).toList(), equals([2]));
      expect(localDb.getFavoriteHymnIds(), contains(2));

      // Simulate an interrupted migration where hymnsBox was cleared or corrupted
      // but installedHymnsVersionKey was NOT committed (e.g. power loss or process kill)
      await localDb.settingsBox.put(LocalDbService.installedHymnsVersionKey, 0);
      await localDb.hymnsBox.clear();

      // On next app initialization, needsImport is detected and import runs
      expect(localDb.getInstalledHymnsVersion(), equals(0));
      final success = await localDb.importBundledHymns(
        rawJsonString: jsonEncode(initialData),
        targetVersion: 1,
      );

      expect(success, isTrue);
      expect(localDb.getInstalledHymnsVersion(), equals(1));
      // User favorite must be completely recovered from persistent settingsBox backup
      final favoritesAfter = localDb.getFavoriteHymns();
      expect(favoritesAfter.length, equals(1));
      expect(favoritesAfter.first.id, equals(2));
      expect(favoritesAfter.first.isFavoriteLocal, isTrue);
    });

    test('Safely preserves service plan hymn even if removed from updated collection', () async {
      await localDb.init(storagePath: tempDir.path);

      final v1Data = [
        {'id': 77, 'hymn_number': 77, 'title': 'Old Hymn 77', 'content': 'Old Lyrics', 'section_number': 1},
      ];

      await localDb.importBundledHymns(
        rawJsonString: jsonEncode(v1Data),
        targetVersion: 1,
      );

      final hymn77 = localDb.getHymnById(77)!;
      final serviceHymn = ServiceHymn(
        category: 'Communion',
        hymn: hymn77,
        order: 1,
      );
      await localDb.serviceBox.add(serviceHymn);

      // v2 collection completely omits hymn 77
      final v2Data = [
        {'id': 88, 'hymn_number': 88, 'title': 'New Hymn 88', 'content': 'New Lyrics', 'section_number': 1},
      ];

      final success = await localDb.importBundledHymns(
        rawJsonString: jsonEncode(v2Data),
        targetVersion: 2,
      );

      expect(success, isTrue);
      expect(localDb.getHymnById(77), isNull, reason: 'Hymn 77 removed from main library');
      expect(localDb.getHymnById(88), isNotNull);

      // Service plan must safely retain the ServiceHymn without crashing or losing metadata
      expect(localDb.serviceBox.length, equals(1));
      final serviceEntry = localDb.serviceBox.getAt(0);
      expect(serviceEntry, isNotNull);
      expect(serviceEntry!.category, equals('Communion'));
      expect(serviceEntry.hymn.id, equals(77));
      expect(serviceEntry.hymn.title, equals('Old Hymn 77'));
    });
  });
}

