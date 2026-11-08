import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_drawer.dart';
import '../providers/hymn_provider.dart';
import 'hymn_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    ref.read(selectedSectionProvider.notifier).state = null;
    ref.read(searchQueryProvider.notifier).state = query;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HymnListScreen(title: 'Search Results')),
    );
  }

  void _navigateToSection(int section, String title) {
    ref.read(selectedSectionProvider.notifier).state = section;
    ref.read(searchQueryProvider.notifier).state = '';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HymnListScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alur Hymns'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              textInputAction: TextInputAction.search,
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
              onSubmitted: _performSearch,
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            _buildBookCard(context, 'Buku Wer', 1),
            const SizedBox(height: 16),
            _buildBookCard(context, 'Koro', 2),
            const SizedBox(height: 16),
            _buildBookCard(context, 'Yellow Book', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, String title, int sectionNum) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), 
          width: 1.5
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _navigateToSection(sectionNum, title),
      child: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
