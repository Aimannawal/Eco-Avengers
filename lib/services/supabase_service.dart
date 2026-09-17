// ============================================================
// SUPABASE SERVICE
// Singleton wrapper untuk SupabaseClient.
// Inisialisasi sekali di main.dart, lalu pakai di seluruh app.
// ============================================================

import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/supabase_constants.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  /// Akses langsung ke Supabase client
  SupabaseClient get client => Supabase.instance.client;

  // ── Inisialisasi ─────────────────────────────────────────

  /// Panggil sekali dari main.dart sebelum runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  // ── Player Identity ───────────────────────────────────────

  /// Ambil atau buat UUID player yang tersimpan di device
  Future<String> getOrCreatePlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    String? playerId = prefs.getString(AppConstants.prefPlayerId);
    if (playerId == null) {
      playerId = const Uuid().v4();
      await prefs.setString(AppConstants.prefPlayerId, playerId);
    }
    return playerId;
  }

  /// Simpan nama player ke local storage
  Future<void> savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefPlayerName, name);
  }

  /// Ambil nama player dari local storage
  Future<String?> getPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefPlayerName);
  }

  // ── Utility ───────────────────────────────────────────────

  /// Generate kode room random 6 huruf kapital
  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random();
    return List.generate(
      AppConstants.roomCodeLength,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
