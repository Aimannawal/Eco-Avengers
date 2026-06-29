import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  static const Color _buttonGreen = Color(0xFFA5C18A);
  static const Color _darkGreen = Color(0xFF4A6741);
  static const Color _buttonBorder = Color(0xFF111111);
  static const Color _goldColor = Color(0xFFFFD700);
  static const Color _silverColor = Color(0xFFD7D7D7);
  static const Color _bronzeColor = Color(0xFFAD8A56);
  static const Color _creamBg = Color(0xFFFAF7F2);

  final List<Map<String, dynamic>> _dummy = const [
    {'name': 'EcoMaster9', 'score': 9820},
    {'name': 'GreenTitan', 'score': 8750},
    {'name': 'TerraNova', 'score': 8130},
    {'name': 'NatureKnight', 'score': 7120},
    {'name': 'CarbonZero', 'score': 6890},
    {'name': 'LeafRunner', 'score': 6400},
    {'name': 'SolarSprite', 'score': 6020},
    {'name': 'EcoWarrior', 'score': 5850},
    {'name': 'ForestGuard', 'score': 5420},
    {'name': 'WindRider', 'score': 5100},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background/kayu.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.08)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.05, -0.12),
                    radius: 1.08,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.12),
                    ],
                    stops: const [0.62, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                if (isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: _buildHeader(context),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Grand Podium
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 24, right: 12, bottom: 24),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: _GrandPodium(players: _dummy.sublist(0, 3)),
                                  ),
                                ),
                              ),
                            ),
                            // Right: Players standings list
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12, right: 24, bottom: 24),
                                child: _PlayerCardList(players: _dummy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Phone portrait layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: _buildHeader(context),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            const SizedBox(height: 8),
                            _GrandPodium(players: _dummy.sublist(0, 3), isCompact: true),
                            const SizedBox(height: 20),
                            Text(
                              'ALL STANDINGS',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.4),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._dummy.map((item) {
                              final idx = _dummy.indexOf(item);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PlayerCard(
                                  rank: idx + 1,
                                  name: item['name'],
                                  score: item['score'],
                                  isTopThree: idx < 3,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          iconSize: 28,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Text(
          'LEADERBOARD',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrandPodium extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final bool isCompact;

  const _GrandPodium({
    Key? key,
    required this.players,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (players.length < 3) return const SizedBox.shrink();

    // Reorder: [2nd, 1st, 3rd] for podium visual structure
    final podiumPlayers = [players[1], players[0], players[2]];

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: LeaderboardScreen._creamBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LeaderboardScreen._buttonBorder,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: LeaderboardScreen._goldColor,
                size: isCompact ? 28 : 36,
              ),
              const SizedBox(width: 8),
              Text(
                'TOP PLAYERS',
                style: GoogleFonts.montserrat(
                  fontSize: isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: LeaderboardScreen._darkGreen,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16 : 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              Expanded(
                child: _PodiumPedestal(
                  player: podiumPlayers[0],
                  rank: 2,
                  pedestalHeight: isCompact ? 70 : 105,
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 8),
              // 1st Place
              Expanded(
                child: _PodiumPedestal(
                  player: podiumPlayers[1],
                  rank: 1,
                  pedestalHeight: isCompact ? 100 : 145,
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 8),
              // 3rd Place
              Expanded(
                child: _PodiumPedestal(
                  player: podiumPlayers[2],
                  rank: 3,
                  pedestalHeight: isCompact ? 55 : 85,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumPedestal extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final double pedestalHeight;
  final bool isCompact;

  const _PodiumPedestal({
    Key? key,
    required this.player,
    required this.rank,
    required this.pedestalHeight,
    required this.isCompact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = player['name'] as String;
    final score = player['score'] as int;

    // Styling configurations based on rank
    Color accentColor;
    Gradient pedestalGradient;
    double avatarRadius;
    IconData? topIcon;

    if (rank == 1) {
      accentColor = LeaderboardScreen._goldColor;
      pedestalGradient = const LinearGradient(
        colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      avatarRadius = isCompact ? 26 : 34;
      topIcon = Icons.workspace_premium_rounded;
    } else if (rank == 2) {
      accentColor = LeaderboardScreen._silverColor;
      pedestalGradient = const LinearGradient(
        colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      avatarRadius = isCompact ? 22 : 28;
    } else {
      accentColor = LeaderboardScreen._bronzeColor;
      pedestalGradient = const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFF92400E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      avatarRadius = isCompact ? 20 : 26;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (topIcon != null) ...[
          Icon(topIcon, color: accentColor, size: isCompact ? 20 : 26),
          const SizedBox(height: 2),
        ],
        // Avatar with crown/rank border
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            border: Border.all(
              color: LeaderboardScreen._buttonBorder,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: LeaderboardScreen._darkGreen.withOpacity(0.85),
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: avatarRadius * 0.9,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Player name
        Text(
          name,
          style: GoogleFonts.montserrat(
            fontSize: isCompact ? 11 : 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Score
        Text(
          '$score',
          style: GoogleFonts.montserrat(
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w800,
            color: LeaderboardScreen._darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        // Pedestal
        Container(
          width: double.infinity,
          height: pedestalHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: pedestalGradient,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            border: const Border(
              top: BorderSide(color: LeaderboardScreen._buttonBorder, width: 3),
              left: BorderSide(color: LeaderboardScreen._buttonBorder, width: 3),
              right: BorderSide(color: LeaderboardScreen._buttonBorder, width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Text(
            '$rank',
            style: GoogleFonts.montserrat(
              fontSize: isCompact ? 24 : 36,
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerCardList extends StatelessWidget {
  final List<Map<String, dynamic>> players;

  const _PlayerCardList({
    Key? key,
    required this.players,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LeaderboardScreen._creamBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LeaderboardScreen._buttonBorder,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALL STANDINGS',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: LeaderboardScreen._darkGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlayerCard(
                    rank: index + 1,
                    name: player['name'],
                    score: player['score'],
                    isTopThree: index < 3,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool isTopThree;

  const _PlayerCard({
    Key? key,
    required this.rank,
    required this.name,
    required this.score,
    required this.isTopThree,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color borderAccentColor = LeaderboardScreen._buttonBorder;
    double borderWidth = 2.0;

    if (isTopThree) {
      if (rank == 1) {
        cardBg = LeaderboardScreen._goldColor.withOpacity(0.18);
        borderAccentColor = LeaderboardScreen._goldColor;
        borderWidth = 2.5;
      } else if (rank == 2) {
        cardBg = LeaderboardScreen._silverColor.withOpacity(0.2);
        borderAccentColor = LeaderboardScreen._silverColor;
        borderWidth = 2.5;
      } else {
        cardBg = LeaderboardScreen._bronzeColor.withOpacity(0.18);
        borderAccentColor = LeaderboardScreen._bronzeColor;
        borderWidth = 2.5;
      }
    } else {
      cardBg = Colors.white.withOpacity(0.65);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopThree ? borderAccentColor : LeaderboardScreen._buttonBorder,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTopThree ? borderAccentColor : Colors.black.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: LeaderboardScreen._buttonBorder,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.montserrat(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: LeaderboardScreen._darkGreen.withOpacity(0.15),
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: LeaderboardScreen._darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score
          Text(
            '$score',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: LeaderboardScreen._darkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
