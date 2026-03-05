import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hymn.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';

final localDbProvider = Provider<LocalDbService>((ref) {
  return LocalDbService();
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class HymnNotifier extends StateNotifier<AsyncValue<List<Hymn>>> {
  HymnNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadHymns();
  }

  final Ref ref;

  Future<void> _loadHymns() async {
    try {
      final localDb = ref.read(localDbProvider);
      
      if (localDb.isOfflineReady()) {
        final localHymns = localDb.getAllHymns();
        state = AsyncValue.data(localHymns);
      } else {
        // Fetch from remote
        await fetchAndSaveHymns();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> fetchAndSaveHymns() async {
    state = const AsyncValue.loading();
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final localDb = ref.read(localDbProvider);

      final hymns = await supabaseService.fetchAllHymns();
      await localDb.saveHymns(hymns);
      
      state = AsyncValue.data(localDb.getAllHymns());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(int hymnId) async {
    final localDb = ref.read(localDbProvider);
    await localDb.toggleFavorite(hymnId);
    
    // Refresh state
    if (state.hasValue) {
      state = AsyncValue.data(localDb.getAllHymns());
    }
  }
}

final hymnProvider = StateNotifierProvider<HymnNotifier, AsyncValue<List<Hymn>>>((ref) {
  return HymnNotifier(ref);
});

// Provides the list of favorites natively
final favoritesProvider = Provider<List<Hymn>>((ref) {
  final hymnsState = ref.watch(hymnProvider);
  return hymnsState.maybeWhen(
    data: (hymns) => hymns.where((h) => h.isFavoriteLocal).toList(),
    orElse: () => [],
  );
});

// A provider for selected section (1=Buku Wer, 2=Koro, 3=Yellow Book)
final selectedSectionProvider = StateProvider<int?>((ref) => null);

// A provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered hymns based on section and query
final filteredHymnsProvider = Provider<List<Hymn>>((ref) {
  final hymnsState = ref.watch(hymnProvider);
  final section = ref.watch(selectedSectionProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return hymnsState.maybeWhen(
    data: (hymns) {
      return hymns.where((h) {
        final matchesSection = section == null || h.sectionNumber == section;
        final matchesQuery = query.isEmpty ||
            h.title.toLowerCase().contains(query) ||
            h.hymnNumber.toString() == query ||
            h.content.toLowerCase().contains(query);
        return matchesSection && matchesQuery;
      }).toList();
    },
    orElse: () => [],
  );
});
