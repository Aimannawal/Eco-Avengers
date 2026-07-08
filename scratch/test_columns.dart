import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/core/constants/supabase_constants.dart';

void main() async {
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );
  final client = Supabase.instance.client;
  try {
    // Attempt to query a non-existent column to see what columns actually exist,
    // or just fetch table description if possible, or select all columns.
    final res = await client.from('room_players').select();
    print("SUCCESS room_players query: $res");
    if (res.isNotEmpty) {
      print("Columns: ${res.first.keys}");
    } else {
      print("No rows in room_players. Trying to check schema via RPC or other table.");
    }
  } catch (e) {
    print("Error querying room_players: $e");
  }

  try {
    final res2 = await client.from('game_states').select();
    print("SUCCESS game_states query: $res2");
    if (res2.isNotEmpty) {
      print("Columns: ${res2.first.keys}");
    }
  } catch (e) {
    print("Error querying game_states: $e");
  }
}
