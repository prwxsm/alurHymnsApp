import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_mode_provider.dart';
import 'hymn_reader_screen.dart';

class ServiceModeScreen extends ConsumerStatefulWidget {
  const ServiceModeScreen({super.key});

  @override
  ConsumerState<ServiceModeScreen> createState() => _ServiceModeScreenState();
}

class _ServiceModeScreenState extends ConsumerState<ServiceModeScreen> {

  @override
  Widget build(BuildContext context) {
    final serviceHymns = ref.watch(serviceModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Mode'),
        actions: [
          if (serviceHymns.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Service',
              onPressed: () {
                ref.read(serviceModeProvider.notifier).clearService();
              },
            ),
        ],
      ),
      body: serviceHymns.isEmpty
          ? const Center(
              child: Text(
                'No hymns in service list yet.\nGo to a hymn and add it to a service.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: serviceHymns.length,
              itemBuilder: (context, index) {
                final serviceHymn = serviceHymns[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text((index + 1).toString()),
                  ),
                  title: Text(serviceHymn.hymn.title),
                  subtitle: Text(serviceHymn.category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(serviceModeProvider.notifier).removeHymnFromService(index);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HymnReaderScreen(hymn: serviceHymn.hymn),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('To add a hymn, browse to it and select "Add to Service" (feature coming soon)')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Hymn'),
      ),
    );
  }
}
