// ============================================================
// ROOM MODELS
// Model class untuk tabel Supabase: game_rooms, room_players,
// dan game_states
// ============================================================

/// Model untuk tabel `game_rooms`
class GameRoom {
  final String id;
  final String roomCode;
  final String hostPlayerId;
  final String difficulty;
  final String status;
  final int maxPlayers;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GameRoom({
    required this.id,
    required this.roomCode,
    required this.hostPlayerId,
    required this.difficulty,
    required this.status,
    required this.maxPlayers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameRoom.fromMap(Map<String, dynamic> map) {
    return GameRoom(
      id: map['id'] as String,
      roomCode: map['room_code'] as String,
      hostPlayerId: map['host_player_id'] as String,
      difficulty: map['difficulty'] as String,
      status: map['status'] as String,
      maxPlayers: map['max_players'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_code': roomCode,
      'host_player_id': hostPlayerId,
      'difficulty': difficulty,
      'status': status,
      'max_players': maxPlayers,
    };
  }

  GameRoom copyWith({
    String? id,
    String? roomCode,
    String? hostPlayerId,
    String? difficulty,
    String? status,
    int? maxPlayers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameRoom(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────

/// Model untuk tabel `room_players`
class RoomPlayer {
  final String id;
  final String roomId;
  final String playerId;
  final String playerName;
  final String? characterId;
  final String? characterName;
  final String? characterAsset;
  final bool isReady;
  final bool isHost;
  final DateTime joinedAt;

  const RoomPlayer({
    required this.id,
    required this.roomId,
    required this.playerId,
    required this.playerName,
    this.characterId,
    this.characterName,
    this.characterAsset,
    required this.isReady,
    required this.isHost,
    required this.joinedAt,
  });

  factory RoomPlayer.fromMap(Map<String, dynamic> map) {
    return RoomPlayer(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      playerId: map['player_id'] as String,
      playerName: map['player_name'] as String,
      characterId: map['character_id'] as String?,
      characterName: map['character_name'] as String?,
      characterAsset: map['character_asset'] as String?,
      isReady: map['is_ready'] as bool,
      isHost: map['is_host'] as bool,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'player_id': playerId,
      'player_name': playerName,
      'character_id': characterId,
      'character_name': characterName,
      'character_asset': characterAsset,
      'is_ready': isReady,
      'is_host': isHost,
    };
  }

  RoomPlayer copyWith({
    String? id,
    String? roomId,
    String? playerId,
    String? playerName,
    String? characterId,
    String? characterName,
    String? characterAsset,
    bool? isReady,
    bool? isHost,
    DateTime? joinedAt,
  }) {
    return RoomPlayer(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      characterId: characterId ?? this.characterId,
      characterName: characterName ?? this.characterName,
      characterAsset: characterAsset ?? this.characterAsset,
      isReady: isReady ?? this.isReady,
      isHost: isHost ?? this.isHost,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────

/// Model untuk tabel `game_states`
class MultiplayerGameState {
  final String id;
  final String roomId;
  final String currentPlayerId;
  final int roundNumber;
  final int energy;
  final int peace;
  final int crisisTokens;
  final int ecoCrisisLevel;
  final String selectedRegion;
  final List<Map<String, dynamic>> actionLog;
  final DateTime updatedAt;

  const MultiplayerGameState({
    required this.id,
    required this.roomId,
    required this.currentPlayerId,
    required this.roundNumber,
    required this.energy,
    required this.peace,
    required this.crisisTokens,
    required this.ecoCrisisLevel,
    required this.selectedRegion,
    required this.actionLog,
    required this.updatedAt,
  });

  factory MultiplayerGameState.fromMap(Map<String, dynamic> map) {
    final rawLog = map['action_log'];
    List<Map<String, dynamic>> log = [];
    if (rawLog is List) {
      log = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return MultiplayerGameState(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      currentPlayerId: map['current_player_id'] as String,
      roundNumber: map['round_number'] as int,
      energy: map['energy'] as int,
      peace: map['peace'] as int,
      crisisTokens: map['crisis_tokens'] as int,
      ecoCrisisLevel: map['eco_crisis_level'] as int,
      selectedRegion: map['selected_region'] as String,
      actionLog: log,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'current_player_id': currentPlayerId,
      'round_number': roundNumber,
      'energy': energy,
      'peace': peace,
      'crisis_tokens': crisisTokens,
      'eco_crisis_level': ecoCrisisLevel,
      'selected_region': selectedRegion,
      'action_log': actionLog,
    };
  }

  MultiplayerGameState copyWith({
    String? id,
    String? roomId,
    String? currentPlayerId,
    int? roundNumber,
    int? energy,
    int? peace,
    int? crisisTokens,
    int? ecoCrisisLevel,
    String? selectedRegion,
    List<Map<String, dynamic>>? actionLog,
    DateTime? updatedAt,
  }) {
    return MultiplayerGameState(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      roundNumber: roundNumber ?? this.roundNumber,
      energy: energy ?? this.energy,
      peace: peace ?? this.peace,
      crisisTokens: crisisTokens ?? this.crisisTokens,
      ecoCrisisLevel: ecoCrisisLevel ?? this.ecoCrisisLevel,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      actionLog: actionLog ?? this.actionLog,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
