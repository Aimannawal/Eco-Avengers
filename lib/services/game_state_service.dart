// ============================================================
// GAME STATE SERVICE
// Semua query ke tabel game_states + realtime stream
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/constants/app_constants.dart';
import '../models/room_model.dart';
import 'supabase_service.dart';

class GameStateService {
  GameStateService._();
  static final GameStateService instance = GameStateService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  // ── INIT ─────────────────────────────────────────────────

  /// Buat game state awal saat host mulai game.
  /// Dipanggil setelah semua player ready.
  Future<MultiplayerGameState> initGameState({
    required String roomId,
    required String hostPlayerId,
    required String difficulty,
    required List<String> playerOrder, // urutan turn
  }) async {
    final tokens = AppConstants.difficultyTokens[difficulty] ??
        AppConstants.difficultyTokens[AppConstants.difficultyNormal]!;

    final data = await _client
        .from(SupabaseConstants.tableGameStates)
        .insert({
          'room_id': roomId,
          'current_player_id': playerOrder.first,
          'round_number': 1,
          'energy': tokens['energy'],
          'peace': tokens['peace'],
          'crisis_tokens': tokens['crisis_tokens'],
          'eco_crisis_level': tokens['eco_crisis_level'],
          'selected_region': 'Africa',
          'sustainable_token_position': 4,
          'crisis_token_position': 0,
          'action_log': [],
        })
        .select()
        .single();

    return MultiplayerGameState.fromMap(data);
  }

  // ── GET ───────────────────────────────────────────────────

  /// Ambil game state satu kali
  Future<MultiplayerGameState?> getGameState(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.tableGameStates)
        .select()
        .eq('room_id', roomId)
        .maybeSingle();

    if (data == null) return null;
    return MultiplayerGameState.fromMap(data);
  }

  // ── UPDATE ────────────────────────────────────────────────

  /// Update token/state setelah suatu aksi.
  /// Hanya field yang di-pass yang akan diupdate.
  Future<MultiplayerGameState> updateGameState(
    String roomId, {
    String? currentPlayerId,
    int? roundNumber,
    int? energy,
    int? peace,
    int? crisisTokens,
    int? ecoCrisisLevel,
    String? selectedRegion,
    int? sustainableTokenPosition,
    int? crisisTokenPosition,
    Map<String, dynamic>? appendActionLog,
  }) async {
    final updates = <String, dynamic>{};

    if (currentPlayerId != null) updates['current_player_id'] = currentPlayerId;
    if (roundNumber != null) updates['round_number'] = roundNumber;
    if (energy != null) updates['energy'] = energy;
    if (peace != null) updates['peace'] = peace;
    if (crisisTokens != null) updates['crisis_tokens'] = crisisTokens;
    if (ecoCrisisLevel != null) updates['eco_crisis_level'] = ecoCrisisLevel;
    if (selectedRegion != null) updates['selected_region'] = selectedRegion;
    if (sustainableTokenPosition != null) updates['sustainable_token_position'] = sustainableTokenPosition;
    if (crisisTokenPosition != null) updates['crisis_token_position'] = crisisTokenPosition;

    // Append to action_log menggunakan jsonb_build_array
    if (appendActionLog != null) {
      // Ambil log lama dulu, append, simpan
      final current = await getGameState(roomId);
      if (current != null) {
        final newLog = [...current.actionLog, appendActionLog];
        updates['action_log'] = newLog;
      }
    }

    if (updates.isEmpty) {
      final state = await getGameState(roomId);
      return state!;
    }

    final data = await _client
        .from(SupabaseConstants.tableGameStates)
        .update(updates)
        .eq('room_id', roomId)
        .select()
        .single();

    return MultiplayerGameState.fromMap(data);
  }

  /// Sync player's hand cards to action log (for multiplayer)
  Future<MultiplayerGameState> syncPlayerHandCards({
    required String roomId,
    required String playerId,
    required List<String> handCards,
  }) async {
    return updateGameState(
      roomId,
      appendActionLog: {
        'type': 'hand_cards_sync',
        'player_id': playerId,
        'cards': handCards,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ── NEXT TURN ─────────────────────────────────────────────

  /// Pindahkan giliran ke player berikutnya dalam daftar
  Future<MultiplayerGameState> nextTurn({
    required String roomId,
    required List<String> playerOrder,
    required String currentPlayerId,
  }) async {
    final currentIndex = playerOrder.indexOf(currentPlayerId);
    final nextIndex = (currentIndex + 1) % playerOrder.length;
    final nextPlayerId = playerOrder[nextIndex];

    // Tambah round number jika sudah satu putaran penuh
    final isNewRound = nextIndex == 0;
    final current = await getGameState(roomId);
    final newRound = isNewRound ? (current?.roundNumber ?? 1) + 1 : null;

    return updateGameState(
      roomId,
      currentPlayerId: nextPlayerId,
      roundNumber: newRound,
      appendActionLog: {
        'type': 'turn_end',
        'player_id': currentPlayerId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ── REALTIME STREAM ───────────────────────────────────────

  /// Subscribe ke perubahan game_states untuk room ini.
  /// Callback dipanggil setiap ada INSERT atau UPDATE.
  RealtimeChannel streamGameState({
    required String roomId,
    required void Function(MultiplayerGameState state) onUpdate,
  }) {
    return _client
        .channel('${SupabaseConstants.channelGamePrefix}$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableGameStates,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(MultiplayerGameState.fromMap(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.tableGameStates,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(MultiplayerGameState.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  // ── BROADCAST ─────────────────────────────────────────────

  /// Kirim event broadcast cepat (tanpa DB) ke semua player di room.
  /// Dipakai untuk animasi dice, hover card, dll.
  RealtimeChannel createBroadcastChannel(String roomId) {
    return _client.channel(
      '${SupabaseConstants.channelGamePrefix}broadcast_$roomId',
    );
  }

  Future<void> broadcastGameAction({
    required RealtimeChannel channel,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    await channel.sendBroadcastMessage(
      event: event,
      payload: payload,
    );
  }
}
