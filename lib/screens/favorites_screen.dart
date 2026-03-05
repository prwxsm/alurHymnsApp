import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hymn_provider.dart';
import 'hymn_reader_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                'No favorite hymns yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final hymn = favorites[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(
                      hymn.hymnNumber.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                  title: Text(hymn.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_getSectionName(hymn.sectionNumber)),
                  trailing: IconButton(
                    icon: Icon(hymn.isFavoriteLocal ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                    onPressed: () {
                      ref.read(hymnProvider.notifier).toggleFavorite(hymn.id);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HymnReaderScreen(hymn: hymn),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _getSectionName(int sectionNumber) {
    switch (sectionNumber) {
      case 1:
        return 'Buku Wer';
      case 2:
        return 'Koro';
      case 3:
      default:
        return 'Yellow Book';
    }
  }
}
