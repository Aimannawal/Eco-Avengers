// ============================================================
// SUPABASE CONSTANTS
// Isi SUPABASE_URL dan SUPABASE_ANON_KEY dengan kredensial kamu
// dari: Supabase Dashboard → Settings → API
// ============================================================

class SupabaseConstants {
  SupabaseConstants._();

  // TODO: Ganti dengan URL project Supabase kamu
  static const String supabaseUrl = 'https://fladbniabaafzpzxyidd.supabase.co';

  // TODO: Ganti dengan anon key project Supabase kamu
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZsYWRibmlhYmFhZnpwenh5aWRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3NzgzODksImV4cCI6MjA5NzM1NDM4OX0.1jLc2NcpYPCmS0RSTVnAjbn6qiueWIfNj54pzx8w4LM';

  // ── Table Names ──────────────────────────────────────────
  static const String tableGameRooms = 'game_rooms';
  static const String tableRoomPlayers = 'room_players';
  static const String tableGameStates = 'game_states';
  static const String tablePlayerProfiles = 'player_profiles';
  static const String tableGameResults = 'game_results';

  // ── Channel Prefixes (Supabase Realtime) ─────────────────
  static const String channelRoomPrefix = 'room:';
  static const String channelGamePrefix = 'game:';

  // ── Broadcast Event Names ─────────────────────────────────
  static const String eventGameAction = 'game_action';
  static const String eventDiceRoll = 'dice_roll';
  static const String eventCardPlayed = 'card_played';
}
