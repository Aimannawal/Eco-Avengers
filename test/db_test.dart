import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boardgame/core/constants/supabase_constants.dart';

void main() {
  test('Query Supabase columns', () async {
    SharedPreferences.setMockInitialValues({});
    
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );
    final client = Supabase.instance.client;
    try {
      final res = await client.from('room_players').select().limit(1);
      print("SUCCESS room_players query: $res");
      if (res.isNotEmpty) {
        print("room_players Columns: ${res.first.keys}");
      }
    } catch (e) {
      print("Error querying room_players: $e");
    }

    try {
      final res2 = await client.from('game_states').select().limit(1);
      print("SUCCESS game_states query: $res2");
      if (res2.isNotEmpty) {
        print("game_states Columns: ${res2.first.keys}");
      }
    } catch (e) {
      print("Error querying game_states: $e");
    }
  });
}
