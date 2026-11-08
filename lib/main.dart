import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'services/local_db_service.dart';
import 'providers/settings_provider.dart';
import 'providers/hymn_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local Hive storage and load/upgrade bundled hymns offline
  final localDb = LocalDbService();
  await localDb.init();

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(localDb),
      ],
      child: const AlurHymnApp(),
    ),
  );
}

class AlurHymnApp extends ConsumerWidget {
  const AlurHymnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Alur Hymns',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
