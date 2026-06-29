// ============================================================
// ROOM SERVICE
// Semua query ke tabel game_rooms dan room_players
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/constants/app_constants.dart';
import '../models/room_model.dart';
import 'supabase_service.dart';

class RoomService {
  RoomService._();
  static final RoomService instance = RoomService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  // ── CREATE ROOM ───────────────────────────────────────────

  /// Buat room baru. Return [GameRoom] yang baru dibuat.
  Future<GameRoom> createRoom({
    required String difficulty,
    required String playerName,
  }) async {
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();
    await SupabaseService.instance.savePlayerName(playerName);

    final roomCode = SupabaseService.generateRoomCode();

    // Insert room
    final roomData = await _client
        .from(SupabaseConstants.tableGameRooms)
        .insert({
          'room_code': roomCode,
          'host_player_id': playerId,
          'difficulty': difficulty,
          'status': AppConstants.statusWaiting,
          'max_players': AppConstants.maxPlayers,
        })
        .select()
        .single();

    final room = GameRoom.fromMap(roomData);

    // Insert host sebagai player pertama
    await _client.from(SupabaseConstants.tableRoomPlayers).insert({
      'room_id': room.id,
      'player_id': playerId,
      'player_name': playerName,
      'is_host': true,
      'is_ready': false,
    });

    return room;
  }

  // ── JOIN ROOM ─────────────────────────────────────────────

  /// Join room dengan kode. Return [GameRoom] jika berhasil.
  /// Throws [Exception] jika room tidak ditemukan, penuh, atau sudah mulai.
  Future<GameRoom> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();
    await SupabaseService.instance.savePlayerName(playerName);

    // Cari room by kode
    final roomData = await _client
        .from(SupabaseConstants.tableGameRooms)
        .select()
        .eq('room_code', roomCode.toUpperCase())
        .maybeSingle();

    if (roomData == null) {
      throw Exception('Room dengan kode "$roomCode" tidak ditemukan.');
    }

    final room = GameRoom.fromMap(roomData);

    if (room.status != AppConstants.statusWaiting) {
      throw Exception('Room sudah mulai bermain, tidak bisa join.');
    }

    // Cek jumlah player saat ini
    final playersData = await _client
        .from(SupabaseConstants.tableRoomPlayers)
        .select()
        .eq('room_id', room.id);

    if (playersData.length >= room.maxPlayers) {
      throw Exception('Room sudah penuh (maks ${room.maxPlayers} pemain).');
    }

    // Cek apakah player sudah ada di room (re-join)
    final existing = playersData
        .where((p) => p['player_id'] == playerId)
        .toList();

    if (existing.isEmpty) {
      // Insert player baru
      await _client.from(SupabaseConstants.tableRoomPlayers).insert({
        'room_id': room.id,
        'player_id': playerId,
        'player_name': playerName,
        'is_host': false,
        'is_ready': false,
      });
    }

    return room;
  }

  // ── LEAVE ROOM ────────────────────────────────────────────

  /// Leave room. Jika host yang keluar, hapus entire room.
  Future<void> leaveRoom(String roomId) async {
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();

    // Cek apakah player ini host
    final roomData = await _client
        .from(SupabaseConstants.tableGameRooms)
        .select()
        .eq('id', roomId)
        .maybeSingle();

    if (roomData == null) return;

    final room = GameRoom.fromMap(roomData);

    if (room.hostPlayerId == playerId) {
      // Host keluar → hapus room (cascade hapus semua players & game_state)
      await _client
          .from(SupabaseConstants.tableGameRooms)
          .delete()
          .eq('id', roomId);
    } else {
      // Non-host keluar → hapus dari room_players saja
      await _client
          .from(SupabaseConstants.tableRoomPlayers)
          .delete()
          .eq('room_id', roomId)
          .eq('player_id', playerId);
    }
  }

  // ── UPDATE ROOM STATUS ────────────────────────────────────

  /// Update status room (hanya host yang boleh panggil ini)
  Future<void> updateRoomStatus(String roomId, String status) async {
    await _client
        .from(SupabaseConstants.tableGameRooms)
        .update({'status': status})
        .eq('id', roomId);
  }

  // ── UPDATE CHARACTER ──────────────────────────────────────

  /// Update karakter player yang dipilih dan set is_ready = true
  Future<void> selectCharacter({
    required String roomId,
    required String characterId,
    required String characterName,
    required String characterAsset,
  }) async {
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();

    await _client
        .from(SupabaseConstants.tableRoomPlayers)
        .update({
          'character_id': characterId,
          'character_name': characterName,
          'character_asset': characterAsset,
          'is_ready': true,
        })
        .eq('room_id', roomId)
        .eq('player_id', playerId);
  }

  // ── GET PLAYERS ───────────────────────────────────────────

  /// Ambil semua player dalam room sekali
  Future<List<RoomPlayer>> getPlayers(String roomId) async {
    final data = await _client
        .from(SupabaseConstants.tableRoomPlayers)
        .select()
        .eq('room_id', roomId)
        .order('joined_at');

    return data.map((p) => RoomPlayer.fromMap(p)).toList();
  }

  // ── REALTIME STREAMS ──────────────────────────────────────

  /// Stream perubahan room (status dll)
  RealtimeChannel streamRoom({
    required String roomId,
    required void Function(GameRoom room) onUpdate,
    required void Function() onDelete,
  }) {
    return _client
        .channel('${SupabaseConstants.channelRoomPrefix}$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.tableGameRooms,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(GameRoom.fromMap(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConstants.tableGameRooms,
          callback: (_) => onDelete(),
        )
        .subscribe();
  }

  /// Stream perubahan daftar player di room
  RealtimeChannel streamPlayers({
    required String roomId,
    required void Function(List<RoomPlayer> players) onUpdate,
  }) {
    return _client
        .channel('${SupabaseConstants.channelRoomPrefix}players_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableRoomPlayers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (_) async {
            final players = await getPlayers(roomId);
            onUpdate(players);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.tableRoomPlayers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (_) async {
            final players = await getPlayers(roomId);
            onUpdate(players);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConstants.tableRoomPlayers,
          callback: (_) async {
            final players = await getPlayers(roomId);
            onUpdate(players);
          },
        )
        .subscribe();
  }
}
