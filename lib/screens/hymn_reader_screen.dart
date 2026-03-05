import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hymn.dart';
import '../providers/settings_provider.dart';
import '../providers/hymn_provider.dart';

class HymnReaderScreen extends ConsumerWidget {
  final Hymn hymn;

  const HymnReaderScreen({super.key, required this.hymn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    // We re-watch the specific hymn to keep favorite status updated
    final hymnsState = ref.watch(hymnProvider);
    Hymn currentHymn = hymn;
    
    hymnsState.maybeWhen(
      data: (hymns) {
        try {
          currentHymn = hymns.firstWhere((h) => h.id == hymn.id);
        } catch (e) {
          // keep original if not found
        }
      },
      orElse: () {},
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Hymn ${currentHymn.hymnNumber}'),
        actions: [
          IconButton(
            icon: const Text('Aa-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            tooltip: 'Decrease font size',
            onPressed: () => ref.read(settingsProvider.notifier).decreaseFontSize(),
          ),
          IconButton(
            icon: const Text('Aa+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            tooltip: 'Increase font size',
            onPressed: () => ref.read(settingsProvider.notifier).increaseFontSize(),
          ),
          IconButton(
            icon: Icon(currentHymn.isFavoriteLocal ? Icons.favorite : Icons.favorite_border),
            color: currentHymn.isFavoriteLocal ? Colors.red : null,
            tooltip: 'Favorite',
            onPressed: () {
              ref.read(hymnProvider.notifier).toggleFavorite(currentHymn.id);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currentHymn.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (currentHymn.scriptureReference != null && currentHymn.scriptureReference!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                currentHymn.scriptureReference!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              currentHymn.content,
              textAlign: TextAlign.left, // Left-aligned makes larger texts easier to read, or center if preferred.
              style: TextStyle(
                fontSize: settings.fontSize,
                height: 1.8, // Good line height for readability
              ),
            ),
          ],
        ),
      ),
    );
  }
}
