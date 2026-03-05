import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/hymn_list_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hymn_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            padding: const EdgeInsets.only(left: 16.0, bottom: 24.0, top: 16.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.transparent,
                  child: Image.asset(
                    'assets/final_icon_drawer.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Books'),
            childrenPadding: const EdgeInsets.only(left: 16.0),
            children: [
              ListTile(
                title: const Text('Buku Wer'),
                onTap: () {
                  ref.read(selectedSectionProvider.notifier).state = 1;
                  ref.read(searchQueryProvider.notifier).state = '';
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HymnListScreen(title: 'Buku Wer')),
                  );
                },
              ),
              ListTile(
                title: const Text('Koro'),
                onTap: () {
                  ref.read(selectedSectionProvider.notifier).state = 2;
                  ref.read(searchQueryProvider.notifier).state = '';
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HymnListScreen(title: 'Koro')),
                  );
                },
              ),
              ListTile(
                title: const Text('Yellow Book'),
                onTap: () {
                  ref.read(selectedSectionProvider.notifier).state = 3;
                  ref.read(searchQueryProvider.notifier).state = '';
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HymnListScreen(title: 'Yellow Book')),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Favorites'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
