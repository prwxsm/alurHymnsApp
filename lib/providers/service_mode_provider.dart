import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_hymn.dart';
import 'hymn_provider.dart';

class ServiceModeNotifier extends StateNotifier<List<ServiceHymn>> {
  ServiceModeNotifier(this.ref) : super([]) {
    _loadServiceHymns();
  }

  final Ref ref;

  void _loadServiceHymns() {
    final localDb = ref.read(localDbProvider);
    final hymns = localDb.serviceBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    state = hymns;
  }

  Future<void> addHymnToService(ServiceHymn serviceHymn) async {
    final localDb = ref.read(localDbProvider);
    
    // Auto-assign an id/key or rely on auto-increment
    await localDb.serviceBox.add(serviceHymn);
    _loadServiceHymns();
  }

  Future<void> removeHymnFromService(int index) async {
    final localDb = ref.read(localDbProvider);
    
    // Hive list index is not guaranteed if we delete, better to use key
    if (index >= 0 && index < state.length) {
      final key = localDb.serviceBox.keyAt(index);
      await localDb.serviceBox.delete(key);
      _loadServiceHymns();
    }
  }

  Future<void> clearService() async {
    final localDb = ref.read(localDbProvider);
    await localDb.serviceBox.clear();
    state = [];
  }
}

final serviceModeProvider = StateNotifierProvider<ServiceModeNotifier, List<ServiceHymn>>((ref) {
  return ServiceModeNotifier(ref);
});
