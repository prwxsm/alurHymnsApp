import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hymn_provider.dart';
import 'hymn_reader_screen.dart';

class HymnListScreen extends ConsumerWidget {
  final String title;

  const HymnListScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hymns = ref.watch(filteredHymnsProvider);
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by title, number, or lyrics...',
                fillColor: Theme.of(context).colorScheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
        ),
      ),
      body: hymns.isEmpty
          ? Center(
              child: Text(
                isSearching ? 'No hymns found.' : 'Loading hymns...',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: hymns.length,
              itemBuilder: (context, index) {
                final hymn = hymns[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      hymn.hymnNumber.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(hymn.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    hymn.content.split('\n').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      hymn.isFavoriteLocal ? Icons.favorite : Icons.favorite_border,
                      color: hymn.isFavoriteLocal ? Colors.red : Colors.grey,
                    ),
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
}
