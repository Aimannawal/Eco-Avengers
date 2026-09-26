class EcoIdea {
  final String id;
  final String playerId;
  final String playerName;
  final String cardTitle;
  final String? cardAssetPath;
  final String region;
  final int crisisLevel;
  final String solutionText;
  final DateTime createdAt;

  EcoIdea({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.cardTitle,
    this.cardAssetPath,
    required this.region,
    required this.crisisLevel,
    required this.solutionText,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'player_id': playerId,
        'player_name': playerName,
        'card_title': cardTitle,
        'card_asset_path': cardAssetPath,
        'region': region,
        'crisis_level': crisisLevel,
        'solution_text': solutionText,
        'created_at': createdAt.toIso8601String(),
      };

  factory EcoIdea.fromJson(Map<String, dynamic> json) => EcoIdea(
        id: json['id'] as String? ?? '',
        playerId: json['player_id'] as String? ?? '',
        playerName: json['player_name'] as String? ?? 'Eco Hero',
        cardTitle: json['card_title'] as String? ?? 'Eco Crisis',
        cardAssetPath: json['card_asset_path'] as String?,
        region: json['region'] as String? ?? '',
        crisisLevel: (json['crisis_level'] as num?)?.toInt() ?? 1,
        solutionText: json['solution_text'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
