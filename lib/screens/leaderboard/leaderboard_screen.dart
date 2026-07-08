import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/leaderboard_model.dart';
import '../../services/leaderboard_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart';

// Shared color constants for leaderboard
const Color _lbButtonGreen = Color(0xFFA5C18A);
const Color _lbDarkGreen = Color(0xFF4A6741);
const Color _lbButtonBorder = Color(0xFF111111);
const Color _lbGoldColor = Color(0xFFFFD700);
const Color _lbSilverColor = Color(0xFFD7D7D7);
const Color _lbBronzeColor = Color(0xFFAD8A56);
const Color _lbCreamBg = Color(0xFFFAF7F2);

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {

  late Future<List<PlayerProfile>> _leaderboardFuture;
  String? _myPlayerId;
  String _currentFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = LeaderboardService.instance.getLeaderboard();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await SupabaseService.instance.getOrCreatePlayerId();
    if (mounted) setState(() => _myPlayerId = id);
  }

  void _refresh() {
    setState(() {
      if (_currentFilter == 'ALL') {
        _leaderboardFuture = LeaderboardService.instance.getLeaderboard();
      } else {
        _leaderboardFuture = LeaderboardService.instance.getLeaderboardResults(difficulty: _currentFilter);
      }
    });
  }

  void _setFilter(String filter) {
    if (_currentFilter == filter) return;
    setState(() {
      _currentFilter = filter;
      _refresh();
    });
  }

  void _showPlayerProfile(BuildContext context, PlayerProfile player) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PlayerProfileDialog(player: player),
    );
  }

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
            child: FutureBuilder<List<PlayerProfile>>(
              future: _leaderboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: _buildHeader(),
                      ),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFA5C18A),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: _buildHeader(),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _lbCreamBg.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _lbButtonBorder, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: Colors.black38, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Gagal memuat leaderboard',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text('Coba Lagi',
                                      style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _lbButtonGreen,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final players = snapshot.data ?? [];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    if (isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            child: _buildHeader(),
                          ),
                          Expanded(
                            child: players.isEmpty
                                ? _buildEmpty()
                                : players.length >= 3
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 24, right: 12, bottom: 24),
                                              child: Center(
                                                child: SingleChildScrollView(
                                                  child: _GrandPodium(
                                                    players: players.take(3).toList(),
                                                    myPlayerId: _myPlayerId,
                                                    onTap: (p) =>
                                                        _showPlayerProfile(
                                                            context, p),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 5,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 12, right: 24, bottom: 24),
                                              child: _PlayerCardList(
                                                players: players,
                                                myPlayerId: _myPlayerId,
                                                onTap: (p) =>
                                                    _showPlayerProfile(context, p),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            left: 24, right: 24, bottom: 24),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 600),
                                            child: _PlayerCardList(
                                              players: players,
                                              myPlayerId: _myPlayerId,
                                              onTap: (p) =>
                                                  _showPlayerProfile(context, p),
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: _buildHeader(),
                          ),
                          Expanded(
                            child: players.isEmpty
                                ? _buildEmpty()
                                : ListView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    children: [
                                      if (players.length >= 3)
                                        _GrandPodium(
                                          players: players.take(3).toList(),
                                          isCompact: true,
                                          myPlayerId: _myPlayerId,
                                          onTap: (p) =>
                                              _showPlayerProfile(context, p),
                                        ),
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
                                              color:
                                                  Colors.black.withOpacity(0.4),
                                              offset: const Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...players.asMap().entries.map((e) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 10),
                                          child: _PlayerCard(
                                            rank: e.key + 1,
                                            player: e.value,
                                            isTopThree: e.key < 3,
                                            isMe: e.value.playerId ==
                                                _myPlayerId,
                                            onTap: () => _showPlayerProfile(
                                                context, e.value),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        const Spacer(),
        _buildFilterChip('ALL'),
        _buildFilterChip('Multiplayer'),
        _buildFilterChip('Easy'),
        _buildFilterChip('Normal'),
        _buildFilterChip('Hard'),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _currentFilter.toLowerCase() == label.toLowerCase();
    return GestureDetector(
      onTap: () => _setFilter(label),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _lbButtonGreen : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.montserrat(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _lbCreamBg.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lbButtonBorder, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined,
                color: Color(0xFFFFD700), size: 64),
            const SizedBox(height: 16),
            Text(
              'Belum ada data',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _lbDarkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selesaikan game pertama kamu\ndan jadilah yang pertama!',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _GrandPodium extends StatelessWidget {
  final List<PlayerProfile> players;
  final bool isCompact;
  final String? myPlayerId;
  final void Function(PlayerProfile) onTap;

  const _GrandPodium({
    Key? key,
    required this.players,
    this.isCompact = false,
    this.myPlayerId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (players.length < 3) return const SizedBox.shrink();
    final podiumPlayers = [players[1], players[0], players[2]];

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: _lbCreamBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lbButtonBorder, width: 3),
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
                color: _lbGoldColor,
                size: isCompact ? 28 : 36,
              ),
              const SizedBox(width: 8),
              Text(
                'TOP PLAYERS',
                style: GoogleFonts.montserrat(
                  fontSize: isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: _lbDarkGreen,
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
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(podiumPlayers[0]),
                  child: _PodiumPedestal(
                    player: podiumPlayers[0],
                    rank: 2,
                    pedestalHeight: isCompact ? 70 : 105,
                    isCompact: isCompact,
                    isMe: podiumPlayers[0].playerId == myPlayerId,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(podiumPlayers[1]),
                  child: _PodiumPedestal(
                    player: podiumPlayers[1],
                    rank: 1,
                    pedestalHeight: isCompact ? 100 : 145,
                    isCompact: isCompact,
                    isMe: podiumPlayers[1].playerId == myPlayerId,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(podiumPlayers[2]),
                  child: _PodiumPedestal(
                    player: podiumPlayers[2],
                    rank: 3,
                    pedestalHeight: isCompact ? 55 : 85,
                    isCompact: isCompact,
                    isMe: podiumPlayers[2].playerId == myPlayerId,
                  ),
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
  final PlayerProfile player;
  final int rank;
  final double pedestalHeight;
  final bool isCompact;
  final bool isMe;

  const _PodiumPedestal({
    Key? key,
    required this.player,
    required this.rank,
    required this.pedestalHeight,
    required this.isCompact,
    this.isMe = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    Gradient pedestalGradient;
    double avatarRadius;
    IconData? topIcon;

    if (rank == 1) {
      accentColor = _lbGoldColor;
      pedestalGradient = const LinearGradient(
        colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      avatarRadius = isCompact ? 26 : 34;
      topIcon = Icons.workspace_premium_rounded;
    } else if (rank == 2) {
      accentColor = _lbSilverColor;
      pedestalGradient = const LinearGradient(
        colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      avatarRadius = isCompact ? 22 : 28;
    } else {
      accentColor = _lbBronzeColor;
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
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? const Color(0xFF4CAF50) : accentColor,
            border: Border.all(
              color: isMe ? Colors.white : _lbButtonBorder,
              width: isMe ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: UserAvatar(
            avatarUrl: player.avatarUrl,
            name: player.displayName,
            characterAsset: player.character != null ? 'assets/vector/char/${player.character} Profile.png' : null,
            radius: avatarRadius,
            backgroundColor: _lbDarkGreen.withOpacity(0.85),
            borderColor: Colors.transparent,
            borderWidth: 0,
            fontSize: avatarRadius * 0.9,
          ),
        ),
        const SizedBox(height: 6),
        if (isMe)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'YOU',
              style: GoogleFonts.montserrat(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        Text(
          player.displayName,
          style: GoogleFonts.montserrat(
            fontSize: isCompact ? 11 : 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (player.country != null)
          Text(
            '🌍 ${player.country}',
            style: GoogleFonts.montserrat(
              fontSize: isCompact ? 9 : 10,
              color: Colors.black45,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          '${player.bestScore}',
          style: GoogleFonts.montserrat(
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w800,
            color: _lbDarkGreen,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: pedestalHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: pedestalGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: const Border(
              top: BorderSide(color: _lbButtonBorder, width: 3),
              left: BorderSide(color: _lbButtonBorder, width: 3),
              right: BorderSide(color: _lbButtonBorder, width: 3),
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
  final List<PlayerProfile> players;
  final String? myPlayerId;
  final void Function(PlayerProfile) onTap;

  const _PlayerCardList({
    Key? key,
    required this.players,
    this.myPlayerId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lbCreamBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lbButtonBorder, width: 3),
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
              color: _lbDarkGreen,
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
                    player: player,
                    isTopThree: index < 3,
                    isMe: player.playerId == myPlayerId,
                    onTap: () => onTap(player),
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
  final PlayerProfile player;
  final bool isTopThree;
  final bool isMe;
  final VoidCallback onTap;

  const _PlayerCard({
    Key? key,
    required this.rank,
    required this.player,
    required this.isTopThree,
    required this.isMe,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color borderAccentColor = _lbButtonBorder;
    double borderWidth = 2.0;

    if (isMe) {
      cardBg = const Color(0xFF4CAF50).withOpacity(0.12);
      borderAccentColor = const Color(0xFF4CAF50);
      borderWidth = 2.5;
    } else if (isTopThree) {
      if (rank == 1) {
        cardBg = _lbGoldColor.withOpacity(0.18);
        borderAccentColor = _lbGoldColor;
        borderWidth = 2.5;
      } else if (rank == 2) {
        cardBg = _lbSilverColor.withOpacity(0.2);
        borderAccentColor = _lbSilverColor;
        borderWidth = 2.5;
      } else {
        cardBg = _lbBronzeColor.withOpacity(0.18);
        borderAccentColor = _lbBronzeColor;
        borderWidth = 2.5;
      }
    } else {
      cardBg = Colors.white.withOpacity(0.65);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderAccentColor, width: borderWidth),
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
                color: isMe
                    ? const Color(0xFF4CAF50)
                    : isTopThree
                        ? borderAccentColor
                        : Colors.black.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _lbButtonBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: GoogleFonts.montserrat(
                  color: isMe || isTopThree ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            UserAvatar(
              avatarUrl: player.avatarUrl,
              name: player.displayName,
              characterAsset: player.character != null ? 'assets/vector/${player.character} Profile.png' : null,
              radius: 18.0,
              backgroundColor: _lbDarkGreen.withOpacity(0.15),
              borderColor: Colors.transparent,
              borderWidth: 0,
              fontSize: 15.0,
            ),
            const SizedBox(width: 10),
            // Name + country
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.displayName,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'YOU',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (player.country != null)
                        Text(
                          '🌍 ${player.country}',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.bestScore}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: _lbDarkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'pts',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Player Profile Dialog
// ─────────────────────────────────────────────────────────────

class _PlayerProfileDialog extends StatefulWidget {
  final PlayerProfile player;
  const _PlayerProfileDialog({Key? key, required this.player}) : super(key: key);

  @override
  State<_PlayerProfileDialog> createState() => _PlayerProfileDialogState();
}

class _PlayerProfileDialogState extends State<_PlayerProfileDialog> {
  List<GameResult>? _recentGames;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = await LeaderboardService.instance
          .getRecentResults(widget.player.playerId);
      if (mounted) setState(() { _recentGames = games; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _badgeRow(String assetPath, String label, Color color, int level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Image.asset(assetPath, width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(
                i < level ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: i < level ? color : color.withOpacity(0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF111111), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF4A6741),
                borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: p.avatarUrl,
                    name: p.displayName,
                    characterAsset: p.character != null ? 'assets/vector/${p.character} Profile.png' : null,
                    radius: 28.0,
                    backgroundColor: const Color(0xFFFFD700),
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fontSize: 22.0,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.displayName,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.country != null)
                          Text(
                            '🌍 ${p.country}',
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        if (p.bio != null && p.bio!.isNotEmpty)
                          Text(
                            p.bio!,
                            style: GoogleFonts.montserrat(
                              color: Colors.white60,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _miniStat('SCORE', '${p.bestScore}', const Color(0xFF4A6741)),
                        const SizedBox(width: 8),
                        _miniStat('WINS', '${p.totalWins}', const Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        _miniStat('LOSSES', '${p.totalLosses}', const Color(0xFFEB5757)),
                        const SizedBox(width: 8),
                        _miniStat('WIN%', '${p.winRate}%', const Color(0xFF2196F3)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Badges
                    Text(
                      'BADGES',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A6741),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _badgeRow('assets/vector/Professional Icon Token-Climate Engineering.png', 'Climate Engineering', const Color(0xFFF06292),
                        p.badges['climate'] ?? 0),
                    _badgeRow('assets/vector/Professional Icon Token-Environmental Ecology.png', 'Environmental Ecology', const Color(0xFFED9B3B),
                        p.badges['ecology'] ?? 0),
                    _badgeRow('assets/vector/Professional Icon Token-Energy Science.png', 'Energy Science', const Color(0xFF6C63FF),
                        p.badges['energy'] ?? 0),

                    const SizedBox(height: 16),

                    // Recent games
                    Text(
                      'RECENT GAMES',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A6741),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4A6741),
                          ),
                        ),
                      )
                    else if (_recentGames == null || _recentGames!.isEmpty)
                      Text(
                        'Belum ada riwayat game',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                      )
                    else
                      ..._recentGames!.map((g) => _gameHistoryRow(g)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    IconData icon;
    if (label == 'WINS') {
      icon = Icons.emoji_events_rounded;
    } else if (label == 'LOSSES') {
      icon = Icons.close_rounded;
    } else if (label == 'WIN%') {
      icon = Icons.trending_up_rounded;
    } else {
      icon = Icons.star_rounded;
    }
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameHistoryRow(GameResult g) {
    final isWin = g.isWin;
    final now = DateTime.now();
    final diff = now.difference(g.playedAt);
    String timeAgo;
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        timeAgo = '${diff.inMinutes}m ago';
      } else {
        timeAgo = '${diff.inHours}h ago';
      }
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      final weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][g.playedAt.weekday % 7];
      timeAgo = '$weekday, ${g.playedAt.day}/${g.playedAt.month}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isWin
            ? const Color(0xFF4CAF50).withOpacity(0.08)
            : const Color(0xFFEB5757).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWin
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0xFFEB5757).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Character avatar
          if (g.character != null && g.character!.isNotEmpty)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWin ? const Color(0xFF4CAF50) : const Color(0xFFEB5757),
                  width: 2,
                ),
                image: DecorationImage(
                  image: AssetImage('assets/vector/${g.character} Profile.png'),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -2),
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 2),
              ),
              child: const Icon(Icons.person, size: 22, color: Colors.black38),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isWin ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: isWin ? const Color(0xFF4CAF50) : const Color(0xFFEB5757),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${g.character ?? 'Unknown'} · ${g.region ?? '?'}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Mode icon
                    Icon(
                      g.mode == 'multiplayer'
                          ? FeatherIcons.users
                          : FeatherIcons.user,
                      size: 13,
                      color: g.mode == 'multiplayer'
                          ? const Color(0xFF4A6741)
                          : const Color(0xFF8D6E63),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${g.difficulty ?? 'Normal'} · ${g.winCount}W/${g.loseCount}L',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${g.score}',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4A6741),
                ),
              ),
              Text(
                timeAgo,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
