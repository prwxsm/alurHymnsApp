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
  String? initError;
  try {
    await localDb.init();
  } catch (e) {
    initError = e.toString();
  }

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(localDb),
      ],
      child: AlurHymnApp(initializationError: initError),
    ),
  );
}

class AlurHymnApp extends ConsumerWidget {
  final String? initializationError;

  const AlurHymnApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Alur Hymns',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: initializationError != null
          ? InitializationErrorScreen(errorMessage: initializationError!)
          : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Fallback screen surfaced when initial offline database seeding fails.
/// Allows the user to view the diagnostic message and trigger a clean retry.
class InitializationErrorScreen extends ConsumerStatefulWidget {
  final String errorMessage;

  const InitializationErrorScreen({super.key, required this.errorMessage});

  @override
  ConsumerState<InitializationErrorScreen> createState() => _InitializationErrorScreenState();
}

class _InitializationErrorScreenState extends ConsumerState<InitializationErrorScreen> {
  bool _isRetrying = false;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _currentError = widget.errorMessage;
  }

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      final localDb = ref.read(localDbProvider);
      await localDb.init();
      ref.invalidate(hymnProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentError = e.toString();
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alur Hymns'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to Initialize Hymn Library',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _currentError ?? 'The hymn database could not be loaded.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _isRetrying
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Initialization'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
