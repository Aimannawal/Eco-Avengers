// ============================================================
// LEADERBOARD SERVICE
// Query ke tabel player_profiles dan game_results
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../models/leaderboard_model.dart';
import 'supabase_service.dart';

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  // ── SUBMIT ────────────────────────────────────────────────

  /// Submit hasil game — buat/update profile + log game result
  Future<void> submitResult({
    required String playerId,
    required String displayName,
    String? country,
    String? bio,
    String? character,
    String? region,
    String? difficulty,
    String mode = 'singleplayer',
    required String result, // 'win' or 'lose'
    required int winCount,
    required int loseCount,
    required int score,
    required Map<String, int> badges,
  }) async {
    // 1. Fetch current profile
    final currentProfile = await getPlayerProfile(playerId);
    final isWin = result == 'win';

    if (currentProfile != null) {
      // Update existing profile
      int newTotalWins = currentProfile.totalWins + (isWin ? 1 : 0);
      int newTotalLosses = currentProfile.totalLosses + (!isWin ? 1 : 0);
      int newBestScore = score > currentProfile.bestScore ? score : currentProfile.bestScore;
      
      // Update badges (take max level)
      Map<String, int> newBadges = Map<String, int>.from(currentProfile.badges);
      badges.forEach((key, value) {
        if (!newBadges.containsKey(key) || newBadges[key]! < value) {
          newBadges[key] = value;
        }
      });
      
      int newTotalBadges = newBadges.values.fold(0, (sum, val) => sum + val);

      await _client.from(SupabaseConstants.tablePlayerProfiles).update({
        'display_name': displayName,
        if (country != null) 'country': country,
        if (bio != null) 'bio': bio,
        'total_wins': newTotalWins,
        'total_losses': newTotalLosses,
        'total_badges': newTotalBadges,
        'best_score': newBestScore,
        'badges': newBadges,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('player_id', playerId);
    } else {
      // Insert new profile
      int newTotalBadges = badges.values.fold(0, (sum, val) => sum + val);
      
      await _client.from(SupabaseConstants.tablePlayerProfiles).insert({
        'player_id': playerId,
        'display_name': displayName,
        'country': country,
        'bio': bio,
        'total_wins': isWin ? 1 : 0,
        'total_losses': !isWin ? 1 : 0,
        'total_badges': newTotalBadges,
        'best_score': score,
        'badges': badges,
      });
    }

    // Normalize difficulty to Title Case to match filter values (Hard/Easy/Normal)
    String? normalizedDifficulty;
    if (difficulty != null && difficulty.isNotEmpty) {
      normalizedDifficulty = difficulty[0].toUpperCase() + difficulty.substring(1).toLowerCase();
    }

    // 2. Insert game result
    await _client.from(SupabaseConstants.tableGameResults).insert({
      'player_id': playerId,
      'player_name': displayName,
      'character': character,
      'region': region,
      'difficulty': normalizedDifficulty,
      'mode': mode,
      'result': result,
      'win_count': winCount,
      'lose_count': loseCount,
      'score': score,
      'badges_earned': badges,
    });
  }

  // ── FETCH ─────────────────────────────────────────────────

  /// Ambil top N pemain dari leaderboard
  Future<List<PlayerProfile>> getLeaderboard({int limit = 50}) async {
    final data = await _client
        .from(SupabaseConstants.tablePlayerProfiles)
        .select()
        .order('best_score', ascending: false)
        .limit(limit);

    return (data as List)
        .map((e) => PlayerProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Ambil top N hasil game berdasarkan difficulty (Easy/Normal/Hard)
  Future<List<PlayerProfile>> getLeaderboardResults({String? difficulty, String? mode, int limit = 50}) async {
    var query = _client
        .from(SupabaseConstants.tableGameResults)
        .select('*, player_profiles(*)');
        
    if (difficulty != null && difficulty.toLowerCase() != 'all' && difficulty.toLowerCase() != 'multiplayer') {
      query = query.ilike('difficulty', difficulty);
    }
    
    if (mode != null) {
      if (mode == 'multiplayer') {
        query = query.like('mode', 'multiplayer%');
      } else {
        query = query.eq('mode', mode);
      }
    } else if (difficulty?.toLowerCase() == 'multiplayer') {
      query = query.like('mode', 'multiplayer%');
    }

    final data = await query.order('score', ascending: false).limit(limit);

    final rawList = (data as List).map((e) {
      final ppMap = e['player_profiles'] as Map<String, dynamic>?;
      if (ppMap != null) {
        final pp = PlayerProfile.fromMap(ppMap);
        return PlayerProfile(
          id: pp.id,
          playerId: pp.playerId,
          displayName: pp.displayName,
          country: pp.country,
          avatarInitial: pp.avatarInitial,
          avatarUrl: pp.avatarUrl,
          character: e['character'] as String?,
          bio: pp.bio,
          totalWins: pp.totalWins,
          totalLosses: pp.totalLosses,
          totalBadges: pp.totalBadges,
          bestScore: (e['score'] as num?)?.toInt() ?? 0,
          badges: pp.badges,
          createdAt: pp.createdAt,
          updatedAt: pp.updatedAt,
        );
      }
      return PlayerProfile(
        id: '',
        playerId: e['player_id'] as String,
        displayName: e['player_name'] as String? ?? 'Player',
        totalWins: 0,
        totalLosses: 0,
        totalBadges: 0,
        bestScore: (e['score'] as num?)?.toInt() ?? 0,
        badges: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    // Group by playerId to get unique players (keep the highest score since it's already sorted descending)
    final uniquePlayers = <String, PlayerProfile>{};
    for (final p in rawList) {
      if (!uniquePlayers.containsKey(p.playerId)) {
        uniquePlayers[p.playerId] = p;
      }
    }
    
    return uniquePlayers.values.toList();
  }

  /// Ambil detail match multiplayer berdasarkan room id
  Future<List<GameResult>> getMultiplayerMatchDetails(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.tableGameResults)
        .select('*, player_profiles(avatar_url)')
        .eq('mode', 'multiplayer_$roomId')
        .order('score', ascending: false); // order by score for MVP

    return (data as List).map((e) => GameResult.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Ambil profil satu player
  Future<PlayerProfile?> getPlayerProfile(String playerId) async {
    final data = await _client
        .from(SupabaseConstants.tablePlayerProfiles)
        .select()
        .eq('player_id', playerId)
        .maybeSingle();

    if (data == null) return null;
    return PlayerProfile.fromMap(data);
  }

  /// Ambil 5 game terakhir seorang player
  Future<List<GameResult>> getRecentResults(String playerId, {int limit = 5}) async {
    final data = await _client
        .from(SupabaseConstants.tableGameResults)
        .select()
        .eq('player_id', playerId)
        .order('played_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((e) => GameResult.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
