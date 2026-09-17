// ============================================================
// LEADERBOARD MODELS
// Model class untuk tabel player_profiles dan game_results
// ============================================================

/// Model untuk tabel `player_profiles`
class PlayerProfile {
  final String id;
  final String playerId;
  final String displayName;
  final String? country;
  final String? avatarInitial;
  final String? avatarUrl;
  final String? character;
  final String? bio;
  final int totalWins;
  final int totalLosses;
  final int totalBadges;
  final int bestScore;
  final Map<String, int> badges; // {"climate": 2, "ecology": 1, "energy": 3}
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.id,
    required this.playerId,
    required this.displayName,
    this.country,
    this.avatarInitial,
    this.avatarUrl,
    this.character,
    this.bio,
    required this.totalWins,
    required this.totalLosses,
    required this.totalBadges,
    required this.bestScore,
    required this.badges,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    final rawBadges = map['badges'] as Map<String, dynamic>? ?? {};
    return PlayerProfile(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      displayName: map['display_name'] as String? ?? 'Player',
      country: map['country'] as String?,
      avatarInitial: map['avatar_initial'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      character: map['character'] as String?,
      bio: map['bio'] as String?,
      totalWins: (map['total_wins'] as num?)?.toInt() ?? 0,
      totalLosses: (map['total_losses'] as num?)?.toInt() ?? 0,
      totalBadges: (map['total_badges'] as num?)?.toInt() ?? 0,
      bestScore: (map['best_score'] as num?)?.toInt() ?? 0,
      badges: rawBadges.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String get initial => (avatarInitial?.isNotEmpty == true)
      ? avatarInitial!
      : displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : '?';

  int get winRate => (totalWins + totalLosses) == 0
      ? 0
      : ((totalWins / (totalWins + totalLosses)) * 100).round();
}

/// Model untuk tabel `game_results`
class GameResult {
  final String id;
  final String playerId;
  final String playerName;
  final String? avatarUrl;
  final String? character;
  final String? region;
  final String? difficulty;
  final String mode;
  final String result; // 'win' or 'lose'
  final int winCount;
  final int loseCount;
  final Map<String, int> badgesEarned;
  final int score;
  final DateTime playedAt;

  const GameResult({
    required this.id,
    required this.playerId,
    required this.playerName,
    this.avatarUrl,
    this.character,
    this.region,
    this.difficulty,
    required this.mode,
    required this.result,
    required this.winCount,
    required this.loseCount,
    required this.badgesEarned,
    required this.score,
    required this.playedAt,
  });

  factory GameResult.fromMap(Map<String, dynamic> map) {
    final rawBadges = map['badges_earned'] as Map<String, dynamic>? ?? {};
    return GameResult(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      playerName: map['player_name'] as String? ?? 'Player',
      avatarUrl: (map['player_profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
      character: map['character'] as String?,
      region: map['region'] as String?,
      difficulty: map['difficulty'] as String?,
      mode: map['mode'] as String? ?? 'singleplayer',
      result: map['result'] as String? ?? 'lose',
      winCount: (map['win_count'] as num?)?.toInt() ?? 0,
      loseCount: (map['lose_count'] as num?)?.toInt() ?? 0,
      badgesEarned: rawBadges.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      score: (map['score'] as num?)?.toInt() ?? 0,
      playedAt: DateTime.parse(map['played_at'] as String),
    );
  }

  bool get isWin => result == 'win';
  bool get isMultiplayer => mode.startsWith('multiplayer');
  String? get roomId {
    if (isMultiplayer && mode.contains('_')) {
      return mode.split('_')[1];
    }
    return null;
  }
}
