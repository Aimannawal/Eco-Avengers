import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/leaderboard_model.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/retro_window.dart';
import '../../widgets/user_avatar.dart';

// Shared color constants for leaderboard
const Color _lbButtonGreen = Color(0xFF76B828);
const Color _lbButtonYellow = Color(0xFFFFDB72);
const Color _lbBorderBlack = Color(0xFF111111);
const Color _lbSkyBlue = Color(0xFF3898EC);
const Color _lbSunnyGold = Color(0xFFF5C842);
const Color _lbCreamBg = Color(0xFFFAF7F2);

// Asset paths
const String _bgPath = 'assets/Element Eco Avenger/Start page/bg.png';
const String _rumputPath = 'assets/Element Eco Avenger/Start page/rumput.png';
// Grass mound layer (the mid-ground rolling hills from start page)
const String _grassMoundPath =
    'assets/Element Eco Avenger/Start page/START_20260830_140036_0000.pdf_20260904_082302_0000.png';
const String _mountainPath =
    'assets/Element Eco Avenger/Multiplayer page/START_20260830_140036_0000.pdf_20260904_090402_0000.png';
const String _bubble1Path =
    'assets/Element Eco Avenger/Multiplayer page/START_20260830_140036_0000.pdf_20260904_090255_0000.png';
const String _bubble2Path =
    'assets/Element Eco Avenger/Multiplayer page/START_20260830_140036_0000.pdf_20260904_090233_0000.png';
const String _bubble3Path =
    'assets/Element Eco Avenger/Multiplayer page/START_20260830_140036_0000.pdf_20260904_090342_0000.png';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Selected Tab: 'ALL', 'MULTIPLAYER', 'DIFFICULTY'
  String _selectedTab = 'ALL';

  // Futures
  late Future<List<PlayerProfile>> _allLeaderboardFuture;
  late Future<List<PlayerProfile>> _multiplayerLeaderboardFuture;
  late Future<List<PlayerProfile>> _easyLeaderboardFuture;
  late Future<List<PlayerProfile>> _mediumLeaderboardFuture;
  late Future<List<PlayerProfile>> _hardLeaderboardFuture;

  // Fallback mock players to match concept photos 100% when DB is empty
  static final List<PlayerProfile> _mockAllPlayers = [
    PlayerProfile(
      id: 'mock-1',
      playerId: 'mock-p1',
      displayName: 'TERIRA THE DESTROYER',
      country: 'SPAIN',
      character: 'Climate Engineering',
      totalWins: 24,
      totalLosses: 3,
      totalBadges: 8,
      bestScore: 1210,
      badges: const {'climate': 3, 'ecology': 2, 'energy': 3},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mock-2',
      playerId: 'mock-p2',
      displayName: 'PUTRI',
      country: 'INDONESIA',
      character: 'Environmental Ecology',
      totalWins: 19,
      totalLosses: 5,
      totalBadges: 6,
      bestScore: 960,
      badges: const {'climate': 2, 'ecology': 3, 'energy': 1},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mock-3',
      playerId: 'mock-p3',
      displayName: 'AZHEL MASTER',
      country: 'INDONESIA',
      character: 'Energy Science',
      totalWins: 15,
      totalLosses: 7,
      totalBadges: 5,
      bestScore: 860,
      badges: const {'climate': 1, 'ecology': 2, 'energy': 2},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<PlayerProfile> _mockMultiplayerPlayers = [
    PlayerProfile(
      id: 'mp-1',
      playerId: 'mp-p1',
      displayName: 'Carissa',
      country: 'INDONESIA',
      character: 'Climate Engineering',
      totalWins: 18,
      totalLosses: 2,
      totalBadges: 7,
      bestScore: 960,
      badges: const {'climate': 3, 'ecology': 2, 'energy': 2},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mp-2',
      playerId: 'mp-p2',
      displayName: 'Azhel',
      country: 'INDONESIA',
      character: 'Energy Science',
      totalWins: 14,
      totalLosses: 4,
      totalBadges: 5,
      bestScore: 830,
      badges: const {'climate': 2, 'ecology': 1, 'energy': 2},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mp-3',
      playerId: 'mp-p3',
      displayName: 'Putri',
      country: 'INDONESIA',
      character: 'Environmental Ecology',
      totalWins: 12,
      totalLosses: 6,
      totalBadges: 4,
      bestScore: 830,
      badges: const {'climate': 1, 'ecology': 2, 'energy': 1},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mp-4',
      playerId: 'mp-p4',
      displayName: 'Terira',
      country: 'SPAIN',
      character: 'Climate Engineering',
      totalWins: 10,
      totalLosses: 5,
      totalBadges: 4,
      bestScore: 750,
      badges: const {'climate': 2, 'ecology': 1, 'energy': 1},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'mp-5',
      playerId: 'mp-p5',
      displayName: 'Budi',
      country: 'INDONESIA',
      character: 'Environmental Ecology',
      totalWins: 8,
      totalLosses: 8,
      totalBadges: 3,
      bestScore: 620,
      badges: const {'climate': 1, 'ecology': 1, 'energy': 1},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<PlayerProfile> _mockDiffPlayers = [
    PlayerProfile(
      id: 'diff-1',
      playerId: 'diff-p1',
      displayName: 'Carissa',
      country: 'INDONESIA',
      totalWins: 12,
      totalLosses: 1,
      totalBadges: 5,
      bestScore: 960,
      badges: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'diff-2',
      playerId: 'diff-p2',
      displayName: 'Putri',
      country: 'INDONESIA',
      totalWins: 10,
      totalLosses: 2,
      totalBadges: 4,
      bestScore: 830,
      badges: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    PlayerProfile(
      id: 'diff-3',
      playerId: 'diff-p3',
      displayName: 'Azhel',
      country: 'INDONESIA',
      totalWins: 8,
      totalLosses: 3,
      totalBadges: 3,
      bestScore: 760,
      badges: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _allLeaderboardFuture = LeaderboardService.instance.getLeaderboard();
    _multiplayerLeaderboardFuture =
        LeaderboardService.instance.getLeaderboardResults(mode: 'multiplayer');
    _easyLeaderboardFuture =
        LeaderboardService.instance.getLeaderboardResults(difficulty: 'Easy');
    _mediumLeaderboardFuture =
        LeaderboardService.instance.getLeaderboardResults(difficulty: 'Normal');
    _hardLeaderboardFuture =
        LeaderboardService.instance.getLeaderboardResults(difficulty: 'Hard');
  }

  void _showPlayerProfile(BuildContext context, PlayerProfile player) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PlayerProfileDialog(player: player),
    );
  }

  List<PlayerProfile> _mergeWithMock(
      List<PlayerProfile>? realList, List<PlayerProfile> mockList) {
    if (realList == null || realList.isEmpty) return mockList;
    if (realList.length >= mockList.length) return realList;
    // Pad with mock players
    final merged = List<PlayerProfile>.from(realList);
    for (int i = realList.length; i < mockList.length; i++) {
      merged.add(mockList[i]);
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6EC6FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background Sky & Clouds ──
          Positioned.fill(
            child: Image.asset(
              _bgPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
          ),

          // ── 2. Grass Mound Mid-ground (rolling hills, behind rumput) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = MediaQuery.of(context).size.height;
                return Image.asset(
                  _grassMoundPath,
                  width: double.infinity,
                  height: h * 0.38,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
          ),

          // ── 3. Rumput Foreground & Bunga (topmost ground layer) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = MediaQuery.of(context).size.height;
                return Image.asset(
                  _rumputPath,
                  width: double.infinity,
                  height: h * 0.26,
                  fit: BoxFit.fill,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
          ),

          // ── 3. Main Content Layer ──
          SafeArea(
            child: Column(
              children: [
                // Header (Back button + Trophy + TOP PLAYERS)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _buildTopBar(),
                ),

                // Main Views according to Tab
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildCurrentTabView(),
                  ),
                ),

                // Bottom Tab Navigation Bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 6),
                  child: _buildBottomNav(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BAR: BACK BUTTON + 🏆 TOP PLAYERS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Back button on the left
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _lbButtonYellow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _lbBorderBlack, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: _lbBorderBlack,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _lbBorderBlack,
                  size: 22,
                ),
              ),
            ),
          ),
        ),

        // Centered Pixel Trophy + TOP PLAYERS
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPixelTrophy(),
            const SizedBox(width: 12),
            Text(
              'TOP PLAYERS',
              style: GoogleFonts.pressStart2p(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _lbBorderBlack,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Pixel Trophy Icon
  Widget _buildPixelTrophy() {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Yellow Trophy emoji or custom styled
          const Text(
            '🏆',
            style: TextStyle(fontSize: 32),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM TAB NAVIGATION
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildNavTabButton(
          label: 'ALL',
          tabKey: 'ALL',
          minWidth: 72,
        ),
        const SizedBox(width: 8),
        _buildNavTabButton(
          label: 'MULTIPLAYER',
          tabKey: 'MULTIPLAYER',
          minWidth: 150,
        ),
        const SizedBox(width: 8),
        _buildNavTabButton(
          label: 'EASY NORMAL HARD',
          tabKey: 'DIFFICULTY',
          minWidth: 200,
        ),
      ],
    );
  }

  Widget _buildNavTabButton({
    required String label,
    required String tabKey,
    required double minWidth,
  }) {
    final bool isSelected = _selectedTab == tabKey;
    final Color bgColor = isSelected ? _lbButtonGreen : _lbButtonYellow;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedTab != tabKey) {
            setState(() => _selectedTab = tabKey);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _lbBorderBlack, width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: _lbBorderBlack,
                offset: Offset(1.5, 2),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _lbBorderBlack,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VIEW SELECTOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildCurrentTabView() {
    switch (_selectedTab) {
      case 'MULTIPLAYER':
        return _buildMultiplayerTab();
      case 'DIFFICULTY':
        return _buildDifficultyTab();
      case 'ALL':
      default:
        return _buildAllPodiumTab();
    }
  }

  // =============================================================
  // TAB 1: ALL (Foto 1) - MOUNTAIN PODIUM & 3 SPEECH BUBBLES
  // =============================================================
  Widget _buildAllPodiumTab() {
    return FutureBuilder<List<PlayerProfile>>(
      future: _allLeaderboardFuture,
      builder: (context, snapshot) {
        final players = _mergeWithMock(snapshot.data, _mockAllPlayers);

        final p1 = players.isNotEmpty ? players[0] : _mockAllPlayers[0];
        final p2 = players.length > 1 ? players[1] : _mockAllPlayers[1];
        final p3 = players.length > 2 ? players[2] : _mockAllPlayers[2];

        return LayoutBuilder(
          builder: (context, constraints) {
            // Container dimensions for podium scene
            final double sceneWidth = constraints.maxWidth;
            final double sceneHeight = constraints.maxHeight;

            // Podium width and height proportional to mountain
            final double mountainW =
                (sceneWidth * 0.72).clamp(380.0, 720.0);
            final double mountainH = mountainW * (469 / 816);

            return Center(
              child: SizedBox(
                width: sceneWidth,
                height: sceneHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mountain in the center-bottom
                    Positioned(
                      bottom: (sceneHeight * 0.04).clamp(10.0, 45.0),
                      child: Image.asset(
                        _mountainPath,
                        width: mountainW,
                        height: mountainH,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                    // Bubble #1 (Peak 1 - Top Center)
                    Positioned(
                      top: (sceneHeight * 0.06).clamp(10.0, 70.0),
                      left: (sceneWidth / 2) - (mountainW * 0.42),
                      child: _buildSpeechBubble(
                        bubbleAsset: _bubble1Path,
                        rank: 1,
                        player: p1,
                        avatarOnLeft: true,
                      ),
                    ),

                    // Bubble #2 (Peak 2 - Right Shoulder)
                    Positioned(
                      top: (sceneHeight * 0.28).clamp(80.0, 200.0),
                      left: (sceneWidth / 2) + (mountainW * 0.08),
                      child: _buildSpeechBubble(
                        bubbleAsset: _bubble2Path,
                        rank: 2,
                        player: p2,
                        avatarOnLeft: false, // Avatar circle on top-right
                      ),
                    ),

                    // Bubble #3 (Peak 3 - Left Base)
                    Positioned(
                      bottom: (sceneHeight * 0.18).clamp(60.0, 150.0),
                      right: (sceneWidth / 2) + (mountainW * 0.12),
                      child: _buildSpeechBubble(
                        bubbleAsset: _bubble3Path,
                        rank: 3,
                        player: p3,
                        avatarOnLeft: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Speech Bubble for Podium ---
  Widget _buildSpeechBubble({
    required String bubbleAsset, // Unused, we use the new separated assets
    required int rank,
    required PlayerProfile player,
    required bool avatarOnLeft,
  }) {
    const double avatarSize = 75.0;
    const double medalSize = 55.0;
    
    // Select the correct bubble background and medal based on rank/position
    // If avatar is on left, tail points to the RIGHT (mountain peak) -> buble right.png
    // If avatar is on right, tail points to the LEFT (mountain peak) -> buble left.png
    final String bubbleBg = avatarOnLeft
        ? 'assets/Element Eco Avenger/Multiplayer page/buble right.png'
        : 'assets/Element Eco Avenger/Multiplayer page/buble left.png';
    final String medalIcon = 'assets/Element Eco Avenger/Multiplayer page/$rank.png';

    // The text block
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player.displayName.toUpperCase(),
          style: GoogleFonts.pressStart2p(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: _lbBorderBlack,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        Text(
          '🌍 ${(player.country ?? 'INDONESIA').toUpperCase()}',
          style: GoogleFonts.pressStart2p(
            fontSize: 7.0,
            color: const Color(0xFF444444),
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${player.bestScore}',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _lbBorderBlack,
            height: 1.0,
          ),
        ),
      ],
    );

    // The bubble with text inside
    final Widget textBubble = Container(
      width: 195,
      height: 123, // Maintain 1.58 aspect ratio of the 240x152 asset
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(bubbleBg),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
      padding: EdgeInsets.only(
        left: avatarOnLeft ? 12 : 28, // Padding for tail when tail is on left
        right: avatarOnLeft ? 28 : 12, // Padding for tail when tail is on right
        top: 10,
        bottom: 15,
      ),
      alignment: Alignment.centerLeft,
      child: textBlock,
    );

    // The Avatar Circle
    final Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _lbBorderBlack, width: 2.5),
      ),
      child: ClipOval(child: _buildPlayerAvatar(player)),
    );

    // The Medal
    final Widget medal = Image.asset(
      medalIcon,
      width: medalSize,
      height: medalSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return GestureDetector(
      onTap: () => _showPlayerProfile(context, player),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 270,
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bubble
              Positioned(
                top: 0,
                left: avatarOnLeft ? 60 : null,
                right: avatarOnLeft ? null : 60,
                child: textBubble,
              ),
              // Avatar (on top of bubble)
              Positioned(
                top: 20,
                left: avatarOnLeft ? 0 : null,
                right: avatarOnLeft ? null : 0,
                child: avatar,
              ),
              // Medal (hanging on the opposite corner of the bubble)
              Positioned(
                top: 80,
                left: avatarOnLeft ? 220 : null,
                right: avatarOnLeft ? null : 220,
                child: medal,
              ),
            ],
          ),
        ),
      ),
    );
  }




  // Avatar: show uploaded photo if available, else colorful initial
  Widget _buildPlayerAvatar(PlayerProfile player) {
    if (player.avatarUrl != null && player.avatarUrl!.isNotEmpty) {
      return Image.network(
        player.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(player),
      );
    }
    return _defaultAvatar(player);
  }

  Widget _defaultAvatar(PlayerProfile player) {
    final Color bg = const [
      Color(0xFF3898EC),
      Color(0xFF4CAF50),
      Color(0xFFF5C842),
      Color(0xFFEB5757),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
    ][player.displayName.isNotEmpty ? player.displayName.codeUnitAt(0) % 6 : 0];
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(
        player.initial,
        style: GoogleFonts.pressStart2p(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
  // =============================================================
  // TAB 2: MULTIPLAYER (Foto 2) - PODIUM ON LEFT + ALL STANDINGS
  // =============================================================
  Widget _buildMultiplayerTab() {
    return FutureBuilder<List<PlayerProfile>>(
      future: _multiplayerLeaderboardFuture,
      builder: (context, snapshot) {
        final players =
            _mergeWithMock(snapshot.data, _mockMultiplayerPlayers);

        final p1 = players.isNotEmpty ? players[0] : _mockMultiplayerPlayers[0];
        final p2 =
            players.length > 1 ? players[1] : _mockMultiplayerPlayers[1];
        final p3 =
            players.length > 2 ? players[2] : _mockMultiplayerPlayers[2];

        return LayoutBuilder(
          builder: (context, constraints) {
            final double sceneWidth = constraints.maxWidth;
            final double sceneHeight = constraints.maxHeight;

            // Mountain scaled and positioned on the left side
            final double mountainW =
                (sceneWidth * 0.48).clamp(300.0, 520.0);
            final double mountainH = mountainW * (469 / 816);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left Side: Mountain Podium with 3 bubbles
                  Expanded(
                    flex: 6,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Mountain
                        Positioned(
                          bottom: 10,
                          left: 20,
                          child: Image.asset(
                            _mountainPath,
                            width: mountainW,
                            height: mountainH,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),

                        // Bubble 1 (Peak)
                        Positioned(
                          top: (sceneHeight * 0.08).clamp(10.0, 60.0),
                          left: (mountainW * 0.15).clamp(20.0, 80.0),
                          child: _buildSpeechBubble(
                            bubbleAsset: _bubble1Path,
                            rank: 1,
                            player: p1,
                            avatarOnLeft: true,
                          ),
                        ),

                        // Bubble 2 (Right shoulder)
                        Positioned(
                          top: (sceneHeight * 0.32).clamp(100.0, 180.0),
                          left: (mountainW * 0.35).clamp(80.0, 180.0), // Shifted left to prevent overflow
                          child: _buildSpeechBubble(
                            bubbleAsset: _bubble2Path,
                            rank: 2,
                            player: p2,
                            avatarOnLeft: false,
                          ),
                        ),

                        // Bubble 3 (Left base)
                        Positioned(
                          bottom: (sceneHeight * 0.14).clamp(50.0, 110.0),
                          left: 0,
                          child: _buildSpeechBubble(
                            bubbleAsset: _bubble3Path,
                            rank: 3,
                            player: p3,
                            avatarOnLeft: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right Side: ALL STANDINGS Retro Folder Panel
                  Expanded(
                    flex: 5,
                    child: _buildMultiplayerStandingsPanel(players),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Retro Folder Panel with "ALL STANDINGS" header and ranking capsules
  Widget _buildMultiplayerStandingsPanel(List<PlayerProfile> players) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      decoration: BoxDecoration(
        color: const Color(0xCCB3D9EA), // Translucent ice blue
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _lbBorderBlack, width: 2.8),
        boxShadow: const [
          BoxShadow(
            color: _lbBorderBlack,
            offset: Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Yellow Folder Tab on top-left
          Positioned(
            top: -24,
            left: -2,
            child: _buildFolderTab(),
          ),

          // Speech Bubble "ALL STANDINGS" on top-right
          Positioned(
            top: -36,
            right: 12,
            child: _buildAllStandingsBubble(),
          ),

          // Inner List of ranking capsules
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            child: ListView.separated(
              itemCount: players.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final player = players[index];
                return _buildMultiplayerRankingItem(
                  rank: index + 1,
                  player: player,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Yellow Folder Tab 📁
  Widget _buildFolderTab() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF7E671),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(10),
        ),
        border: Border(
          top: BorderSide(color: _lbBorderBlack, width: 2.8),
          left: BorderSide(color: _lbBorderBlack, width: 2.8),
          right: BorderSide(color: _lbBorderBlack, width: 2.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE2B833),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: _lbBorderBlack, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // White Speech Bubble "ALL STANDINGS"
  Widget _buildAllStandingsBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _lbBorderBlack, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: _lbBorderBlack,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ALL',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _lbBorderBlack,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'STANDINGS',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _lbBorderBlack,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // Capsule Ranking Item in Multiplayer Tab
  Widget _buildMultiplayerRankingItem({
    required int rank,
    required PlayerProfile player,
  }) {
    return GestureDetector(
      onTap: () => _showPlayerProfile(context, player),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Pill Capsule
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2E2), // Classic pill gray
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _lbBorderBlack, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: _lbBorderBlack,
                    offset: Offset(1.5, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank #1, #2, #3
                  Text(
                    '#$rank',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _lbBorderBlack,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Avatar Silhouette Circle
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _lbBorderBlack, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: _lbBorderBlack,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Player Name
                  Expanded(
                    child: Text(
                      player.displayName,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _lbBorderBlack,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),

            // Score below capsule
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${player.bestScore} pts',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _lbBorderBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TAB 3: EASY NORMAL HARD (Foto 3) - 3 RETRO WINDOWS COLUMNS
  // =============================================================
  Widget _buildDifficultyTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // EASY MODE Window
          Expanded(
            child: _buildWindowsClassicColumn(
              title: 'EASY MODE',
              future: _easyLeaderboardFuture,
            ),
          ),
          const SizedBox(width: 14),

          // MEDIUM MODE Window
          Expanded(
            child: _buildWindowsClassicColumn(
              title: 'MEDIUM MODE',
              future: _mediumLeaderboardFuture,
            ),
          ),
          const SizedBox(width: 14),

          // HARD MODE Window
          Expanded(
            child: _buildWindowsClassicColumn(
              title: 'HARD MODE',
              future: _hardLeaderboardFuture,
            ),
          ),
        ],
      ),
    );
  }

  // Retro Windows 95 / Classic Style Window
  Widget _buildWindowsClassicColumn({
    required String title,
    required Future<List<PlayerProfile>> future,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0), // Classic Windows 95 Gray
        border: Border.all(color: _lbBorderBlack, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: _lbBorderBlack,
            offset: Offset(2.5, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Title Bar: Retro Deep Blue with white pixel font
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF000080), // Windows Navy Blue
            alignment: Alignment.center,
            child: Text(
              title,
              style: GoogleFonts.pressStart2p(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Sunken Inner Content Area with Retro Bevel
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4D0C8), // Sunken gray
                border: Border(
                  top: BorderSide(color: Colors.grey.shade700, width: 2),
                  left: BorderSide(color: Colors.grey.shade700, width: 2),
                  bottom: const BorderSide(color: Colors.white, width: 2),
                  right: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
              child: FutureBuilder<List<PlayerProfile>>(
                future: future,
                builder: (context, snapshot) {
                  final players =
                      _mergeWithMock(snapshot.data, _mockDiffPlayers);

                  return Stack(
                    children: [
                      // Capsule List
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 12, 18, 12),
                        itemCount: players.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return _buildClassicPillItem(
                            rank: index + 1,
                            player: player,
                          );
                        },
                      ),

                      // Decorative Windows scrollbar on right
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: 14,
                        child: _buildClassicScrollbar(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Capsule Ranking Item inside Windows Window
  Widget _buildClassicPillItem({
    required int rank,
    required PlayerProfile player,
  }) {
    return GestureDetector(
      onTap: () => _showPlayerProfile(context, player),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _lbBorderBlack, width: 2),
          ),
          child: Row(
            children: [
              // Rank
              Text(
                '#$rank',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: _lbBorderBlack,
                ),
              ),
              const SizedBox(width: 6),

              // Round avatar
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _lbBorderBlack, width: 1.5),
                ),
                child: const Icon(
                  Icons.person,
                  size: 13,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(width: 6),

              // Player Name
              Expanded(
                child: Text(
                  player.displayName,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: _lbBorderBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Score
              Text(
                '${player.bestScore} pts',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: _lbBorderBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Retro Windows Scrollbar decoration
  Widget _buildClassicScrollbar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border(
          left: BorderSide(color: Colors.grey.shade600, width: 1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Up arrow
          Container(
            height: 14,
            color: const Color(0xFFC0C0C0),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_drop_up, size: 14, color: Colors.black),
          ),
          // Scroll thumb
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFC0C0C0),
              border: Border(
                top: const BorderSide(color: Colors.white, width: 1),
                left: const BorderSide(color: Colors.white, width: 1),
                right: BorderSide(color: Colors.grey.shade800, width: 1),
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
          ),
          // Down arrow
          Container(
            height: 14,
            color: const Color(0xFFC0C0C0),
            alignment: Alignment.center,
            child:
                const Icon(Icons.arrow_drop_down, size: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIALOG: DETAIL PROFIL PEMAIN & MATCH DETAIL POPUPS
// Modernized with Fredoka, Outfit & Sky Blue Palette
// ─────────────────────────────────────────────────────────────

class _PlayerProfileDialog extends StatefulWidget {
  final PlayerProfile player;
  // Private widget — no external key needed
  // ignore: unused_element
  const _PlayerProfileDialog({required this.player});

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
      if (mounted) {
        setState(() {
          _recentGames = games;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _badgeRow(String assetPath, String label, Color color, int level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Image.asset(assetPath, width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
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
                color: i < level ? color : color.withValues(alpha: 0.25),
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
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: _lbCreamBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lbBorderBlack, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Sky Blue Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3898EC), Color(0xFF2879C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: p.avatarUrl,
                    name: p.displayName,
                    characterAsset: p.character != null
                        ? 'assets/vector/${p.character} Profile.png'
                        : null,
                    radius: 28.0,
                    backgroundColor: _lbSunnyGold,
                    borderColor: _lbBorderBlack,
                    borderWidth: 2,
                    fontSize: 22.0,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.displayName,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.country != null)
                          Text(
                            '🌍 ${p.country}',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (p.bio != null && p.bio!.isNotEmpty)
                          Text(
                            p.bio!,
                            style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontSize: 12,
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
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 24),
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
                        _miniStat(
                            'SCORE', '${p.bestScore}', const Color(0xFF3898EC)),
                        const SizedBox(width: 8),
                        _miniStat(
                            'WINS', '${p.totalWins}', const Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        _miniStat('LOSSES', '${p.totalLosses}',
                            const Color(0xFFEB5757)),
                        const SizedBox(width: 8),
                        _miniStat('WIN%', '${p.winRate}%',
                            const Color(0xFFF5C842)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Badges
                    Text(
                      'BADGES',
                      style: GoogleFonts.fredoka(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _lbBorderBlack,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _badgeRow(
                        'assets/vector/Professional Icon Token-Climate Engineering.png',
                        'Climate Engineering',
                        const Color(0xFFF06292),
                        p.badges['climate'] ?? 0),
                    _badgeRow(
                        'assets/vector/Professional Icon Token-Environmental Ecology.png',
                        'Environmental Ecology',
                        const Color(0xFFED9B3B),
                        p.badges['ecology'] ?? 0),
                    _badgeRow(
                        'assets/vector/Professional Icon Token-Energy Science.png',
                        'Energy Science',
                        const Color(0xFF6C63FF),
                        p.badges['energy'] ?? 0),

                    const SizedBox(height: 16),

                    // Recent games
                    Text(
                      'RECENT GAMES',
                      style: GoogleFonts.fredoka(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _lbBorderBlack,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _lbSkyBlue,
                          ),
                        ),
                      )
                    else if (_recentGames == null || _recentGames!.isEmpty)
                      Text(
                        'Belum ada riwayat game',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.black45,
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
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
      final weekday = [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat'
      ][g.playedAt.weekday % 7];
      timeAgo = '$weekday, ${g.playedAt.day}/${g.playedAt.month}';
    }

    Widget rowContent = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isWin
            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
            : const Color(0xFFEB5757).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWin
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFFEB5757).withValues(alpha: 0.25),
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
                  color: isWin
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEB5757),
                  width: 2,
                ),
                image: DecorationImage(
                  image: AssetImage(
                      'assets/vector/${g.character} Profile.png'),
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
              child:
                  const Icon(Icons.person, size: 22, color: Colors.black38),
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
                      color: isWin
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEB5757),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${g.character ?? 'Unknown'} · ${g.region ?? '?'}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                    Icon(
                      g.isMultiplayer
                          ? FeatherIcons.users
                          : FeatherIcons.user,
                      size: 13,
                      color: g.isMultiplayer
                          ? const Color(0xFF3898EC)
                          : const Color(0xFF8D6E63),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${g.difficulty ?? 'Normal'} · ${g.winCount}W/${g.loseCount}L',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
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
                style: GoogleFonts.fredoka(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3898EC),
                ),
              ),
              Text(
                timeAgo,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (g.isMultiplayer) {
            if (g.roomId != null) {
              _showMultiplayerDetailPopup(g.roomId!);
            } else {
              _showNoDetailDialog();
            }
          } else {
            _showSingleplayerDetailPopup(g);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: rowContent,
      ),
    );
  }

  void _showNoDetailDialog() {
    showRetroAlertDialog(
      context: context,
      title: 'Match Info',
      message: 'Detail lengkap untuk match multiplayer ini tidak tersimpan.',
      icon: Icons.info_outline,
    );
  }

  void _showSingleplayerDetailPopup(GameResult g) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _lbCreamBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lbBorderBlack, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SINGLEPLAYER MATCH',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _lbBorderBlack,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip('Difficulty', g.difficulty ?? 'Normal'),
                  _statChip('Result', g.result.toUpperCase()),
                  _statChip('Score', '${g.score}'),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lbSkyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.fredoka(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiplayerDetailPopup(String roomId) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => FutureBuilder<List<GameResult>>(
        future: LeaderboardService.instance.getMultiplayerMatchDetails(roomId),
        builder: (context, snap) {
          final results = snap.data ?? [];
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _lbCreamBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _lbBorderBlack, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MULTIPLAYER MATCH DETAILS',
                    style: GoogleFonts.fredoka(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _lbBorderBlack,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: _lbSkyBlue),
                    )
                  else if (results.isEmpty)
                    Text('Data match tidak ditemukan',
                        style: GoogleFonts.outfit())
                  else
                    ...results.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(r.playerName,
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text('${r.score} pts',
                                  style: GoogleFonts.fredoka(
                                      fontWeight: FontWeight.w700,
                                      color: _lbSkyBlue)),
                            ],
                          ),
                        )),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lbSkyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Tutup',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.fredoka(
                fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
