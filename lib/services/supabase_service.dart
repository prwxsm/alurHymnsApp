import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hymn.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Hymn>> fetchAllHymns() async {
    try {
      final response = await _client
          .from('hymns')
          .select()
          .order('section_number', ascending: true)
          .order('hymn_number', ascending: true);

      final List<dynamic> data = response;
      return data.map((json) => Hymn.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching hymns from Supabase: $e');
      rethrow;
    }
  }
}
