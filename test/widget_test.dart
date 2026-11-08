import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:alur_hymn_app/main.dart';
import 'package:alur_hymn_app/providers/hymn_provider.dart';
import 'package:alur_hymn_app/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDbService localDb;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_');
    localDb = LocalDbService();
    await localDb.init(storagePath: tempDir.path);

    // Seed test hymns for the 3 sections
    final testHymns = [
      {'id': 1, 'hymn_number': 1, 'title': 'Buku Wer Hymn 1', 'content': 'Content 1', 'section_number': 1},
      {'id': 203, 'hymn_number': 1, 'title': 'Koro Hymn 1', 'content': 'Content 2', 'section_number': 2},
      {'id': 233, 'hymn_number': 1, 'title': 'Yellow Book Hymn 1', 'content': 'Content 3', 'section_number': 3},
    ];

    await localDb.importBundledHymns(
      rawJsonString: jsonEncode(testHymns),
      targetVersion: 1,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('App displays home screen with books and search bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDbProvider.overrideWithValue(localDb),
        ],
        child: const AlurHymnApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app title
    expect(find.text('Alur Hymns'), findsOneWidget);

    // Verify search hint
    expect(find.text('Search by title, number, or lyrics...'), findsOneWidget);

    // Verify the three hymn sections appear
    expect(find.text('Buku Wer'), findsOneWidget);
    expect(find.text('Koro'), findsOneWidget);
    expect(find.text('Yellow Book'), findsOneWidget);

    // Tap Buku Wer section and navigate to list screen
    await tester.tap(find.text('Buku Wer'));
    await tester.pumpAndSettle();

    // Verify we navigated to the Buku Wer list
    expect(find.text('Buku Wer Hymn 1'), findsOneWidget);

    // Return to home screen
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Test offline search by entering text in the search bar and submitting
    await tester.enterText(find.byType(TextField), 'Yellow');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Verify search results screen and matching hymn from Yellow Book
    expect(find.text('Search Results'), findsOneWidget);
    expect(find.text('Yellow Book Hymn 1'), findsOneWidget);
  });
}
