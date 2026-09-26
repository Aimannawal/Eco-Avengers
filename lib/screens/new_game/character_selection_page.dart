import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/room_model.dart';
import '../../services/room_service.dart';
import '../../services/game_state_service.dart';
import 'game_play_screen.dart';

class CharacterOption {
  final String title;
  final String description;
  final String assetPath;
  final Color accentColor;

  const CharacterOption({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.accentColor,
  });
}

class CharacterSelectionPage extends StatefulWidget {
  final String difficulty;
  final List<CharacterOption> characters;

  // Multiplayer params (null = single player)
  final String? multiplayerRoomId;
  final List<RoomPlayer>? multiplayerPlayers;
  final String? myPlayerId;

  const CharacterSelectionPage({
    super.key,
    required this.difficulty,
    required this.characters,
    this.multiplayerRoomId,
    this.multiplayerPlayers,
    this.myPlayerId,
  });

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  bool _isMultiplayer = false;
  bool _characterSelected = false;
  bool _waitingForOthers = false;
  List<RoomPlayer> _players = [];
  RealtimeChannel? _playersChannel;

  @override
  void initState() {
    super.initState();
    _isMultiplayer = widget.multiplayerRoomId != null;
    _players = widget.multiplayerPlayers ?? [];

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);

    if (_isMultiplayer) {
      _subscribeToPlayers();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatCtrl.dispose();
    _playersChannel?.unsubscribe();
    super.dispose();
  }

  // ── Multiplayer helpers ───────────────────────────────────

  void _subscribeToPlayers() {
    final roomId = widget.multiplayerRoomId!;
    _playersChannel = RoomService.instance.streamPlayers(
      roomId: roomId,
      onUpdate: _onPlayersUpdated,
    );
  }

  void _onPlayersUpdated(List<RoomPlayer> players) {
    if (!mounted) return;
    setState(() => _players = players);
    if (_characterSelected) {
      _checkAllReady(players);
    }
  }

  void _checkAllReady(List<RoomPlayer> players) {
    final allReady = players.isNotEmpty && players.every((p) => p.isReady);
    if (allReady) {
      _navigateToMultiplayerGame(players);
    }
  }

  Future<void> _navigateToMultiplayerGame(List<RoomPlayer> players) async {
    if (!mounted) return;
    final roomId = widget.multiplayerRoomId!;
    final myPlayerId = widget.myPlayerId!;

    final me = players.firstWhere(
      (p) => p.playerId == myPlayerId,
      orElse: () => players.first,
    );

    MultiplayerGameState? gameState;
    final isHost = players.any(
      (p) => p.playerId == myPlayerId && p.isHost,
    );

    if (isHost) {
      try {
        final sortedPlayers = List<RoomPlayer>.from(players)
          ..sort((a, b) {
            int cmp = a.joinedAt.compareTo(b.joinedAt);
            if (cmp == 0) return a.playerId.compareTo(b.playerId);
            return cmp;
          });

        gameState = await GameStateService.instance.initGameState(
          roomId: roomId,
          hostPlayerId: myPlayerId,
          difficulty: widget.difficulty,
          playerOrder: sortedPlayers.map((p) => p.playerId).toList(),
        );
        await RoomService.instance.updateRoomStatus(roomId, 'playing');
      } catch (_) {
        gameState = await GameStateService.instance.getGameState(roomId);
      }
    } else {
      for (int i = 0; i < 10; i++) {
        gameState = await GameStateService.instance.getGameState(roomId);
        if (gameState != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(
          selectedCharacterId: me.characterId ?? 'unknown',
          selectedCharacterName: me.characterName ?? 'Unknown',
          selectedDifficulty: widget.difficulty,
          characterAccentColor: _getCharacterColor(me.characterId),
          characterAssetPath: me.characterAsset,
          selectedRegion: '',
          multiplayerRoomId: roomId,
          multiplayerGameState: gameState,
          multiplayerPlayers: players,
          myPlayerId: myPlayerId,
        ),
      ),
    );
  }

  Color _getCharacterColor(String? characterId) {
    for (final c in widget.characters) {
      if (c.title.toLowerCase().replaceAll(' ', '_') == characterId) {
        return c.accentColor;
      }
    }
    return const Color(0xFF38A3A5);
  }

  /// Check if a character is already taken by another player in multiplayer
  bool _isCharacterTaken(String characterTitle) {
    if (!_isMultiplayer) return false;
    final characterId = characterTitle.toLowerCase().replaceAll(' ', '_');
    return _players.any((player) => 
      player.characterId == characterId && 
      player.playerId != widget.myPlayerId
    );
  }

  /// Get the player who took a character (null if not taken or taken by me)
  RoomPlayer? _getTakenByPlayer(String characterTitle) {
    if (!_isMultiplayer) return null;
    final characterId = characterTitle.toLowerCase().replaceAll(' ', '_');
    try {
      return _players.firstWhere((player) => 
        player.characterId == characterId && 
        player.playerId != widget.myPlayerId
      );
    } catch (_) {
      return null;
    }
  }

  // ── Navigation ────────────────────────────────────────────

  void _select(CharacterOption character) {
    if (_isMultiplayer) {
      _selectMultiplayer(character);
    } else {
      _selectSinglePlayer(character);
    }
  }

  void _selectSinglePlayer(CharacterOption character) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(
          selectedCharacterId: character.title.toLowerCase().replaceAll(' ', '_'),
          selectedCharacterName: character.title,
          selectedDifficulty: widget.difficulty,
          characterAccentColor: character.accentColor,
          characterAssetPath: character.assetPath,
          selectedRegion: '',
        ),
      ),
    );
  }

  Future<void> _selectMultiplayer(CharacterOption character) async {
    if (_characterSelected) return;
    setState(() {
      _characterSelected = true;
      _waitingForOthers = true;
    });

    try {
      await RoomService.instance.selectCharacter(
        roomId: widget.multiplayerRoomId!,
        characterId: character.title.toLowerCase().replaceAll(' ', '_'),
        characterName: character.title,
        characterAsset: character.assetPath,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _characterSelected = false;
          _waitingForOthers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select character: $e')),
        );
      }
    }
  }


  // ─────────────────────────────────────────────────────────
  // RESPONSIVE 2-ROW CARDS LAYOUT (CANVA DESIGN): 
  // Top Row: 3 cards, Bottom Row: 2 cards (centered) with full Character Sheet (Badges included)
  // ─────────────────────────────────────────────────────────
  Widget _buildCardsLayout() {
    return LayoutBuilder(
      builder: (context, cardArea) {
        final double maxH = cardArea.maxHeight;
        final double maxW = cardArea.maxWidth;

        // Character Sheet aspect ratio is ~1.48:1 (width:height)
        const double cardAspect = 1.48;
        const double rowSpacing = 8.0;
        const double colSpacing = 12.0;

        // Use 78% of available space to guarantee cards fit comfortably
        // inside the parchment without touching or exceeding any edges
        final double safeW = maxW * 0.78;
        final double safeH = maxH * 0.77;

        final double widthBasedCardWidth = (safeW - (colSpacing * 2)) / 3;
        final double widthBasedCardHeight = widthBasedCardWidth / cardAspect;

        final double heightBasedCardHeight = (safeH - rowSpacing) / 2;

        // Take whichever dimension is more constraining
        double cardHeight = math.min(widthBasedCardHeight, heightBasedCardHeight);
        double cardWidth = cardHeight * cardAspect;

        // Split characters into row 1 (first 3) and row 2 (remaining 2)
        final topRow = widget.characters.take(3).toList();
        final bottomRow = widget.characters.skip(3).toList();

        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Row: 3 cards (Energy Scientist, Ecologist, Environmental Activist)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < topRow.length; i++) ...[
                      _CharacterCard(
                        character: topRow[i],
                        onTap: (_characterSelected ||
                                _isCharacterTaken(topRow[i].title))
                            ? null
                            : () => _select(topRow[i]),
                        takenBy: _getTakenByPlayer(topRow[i].title),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),
                      if (i != topRow.length - 1)
                        SizedBox(width: colSpacing),
                    ],
                  ],
                ),
                SizedBox(height: rowSpacing),
                // Bottom Row: 2 cards (Policymaker, Climate Engineer) centered
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < bottomRow.length; i++) ...[
                      _CharacterCard(
                        character: bottomRow[i],
                        onTap: (_characterSelected ||
                                _isCharacterTaken(bottomRow[i].title))
                            ? null
                            : () => _select(bottomRow[i]),
                        takenBy: _getTakenByPlayer(bottomRow[i].title),
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                      ),
                      if (i != bottomRow.length - 1)
                        SizedBox(width: colSpacing),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/Element Eco Avenger/select char/image-removebg-preview (14).png',
                ),
                fit: BoxFit.fill,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Color(0xFF8B5E3C),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'CHARACTER SELECTED! ✓',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vt323(
                    fontSize: 22,
                    color: const Color(0xFF5C3D1E),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Waiting for other players...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vt323(
                    fontSize: 18,
                    color: const Color(0xFF8B5E3C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_players.where((p) => p.isReady).length}/${_players.length} ready',
                  style: GoogleFonts.vt323(
                    fontSize: 20,
                    color: const Color(0xFF5C3D1E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pixel world map background
          Image.asset(
            'assets/Element Eco Avenger/select char/image.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.none,
          ),
          Container(color: Colors.black.withOpacity(0.15)),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final isPhone = constraints.maxWidth < 480;

                  return Stack(
                    children: [
                      // Inner Stack for Paper Background & Anchored Decorations
                      Positioned(
                        top: isPhone ? 60 : 75,
                        left: isPhone ? 20 : 50,
                        right: isPhone ? 20 : 50,
                        bottom: isPhone ? 20 : 30,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. The Main Paper Background
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 18,
                                      offset: const Offset(4, 6),
                                    ),
                                  ],
                                  image: const DecorationImage(
                                    image: AssetImage(
                                      'assets/Element Eco Avenger/select char/image-removebg-preview (14).png',
                                    ),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: isPhone ? 38 : 52,
                                    bottom: isPhone ? 22 : 36,
                                    left: isPhone ? 15 : 25,
                                    right: isPhone ? 15 : 25,
                                  ),
                                  child: _buildCardsLayout(),
                                ),
                              ),
                            ),

                            // 2. Floating corner decorations anchored to the paper
                            // Top-Left Rolled Scroll
                            _FloatingDecor(
                              animation: _floatAnim,
                              top: isPhone ? -30 : -45,
                              left: isPhone ? -35 : -55,
                              floatAmount: 6,
                              child: Image.asset(
                                'assets/Element Eco Avenger/select char/image-removebg-preview (13).png',
                                width: isPhone ? 110 : (isWide ? 190 : 160),
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Bottom-Left Cloud
                            _FloatingDecor(
                              animation: _floatAnim,
                              bottom: isPhone ? -30 : -50,
                              left: isPhone ? -30 : -50,
                              floatAmount: 8,
                              child: Image.asset(
                                'assets/Element Eco Avenger/select char/image-removebg-preview (10).png',
                                width: isPhone ? 140 : (isWide ? 220 : 180),
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Bottom-Right Torn Paper
                            _FloatingDecor(
                              animation: _floatAnim,
                              bottom: isPhone ? -40 : -70,
                              right: isPhone ? -50 : -80,
                              floatAmount: -5,
                              child: Image.asset(
                                'assets/Element Eco Avenger/select char/image-removebg-preview (11).png',
                                width: isPhone ? 100 : (isWide ? 180 : 150),
                                fit: BoxFit.contain,
                              ),
                            ),

                            // 3. Title Parchment Banner (centered, overlapping top edge)
                            Positioned(
                              top: isPhone ? -45 : -70,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/Element Eco Avenger/select char/image-removebg-preview (12).png',
                                      width: isPhone ? 280 : (isWide ? 500 : 380),
                                      fit: BoxFit.contain,
                                    ),
                                    if (_isMultiplayer) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF8B5E3C), width: 2),
                                        ),
                                        child: Text(
                                          '${_players.where((p) => p.isReady).length}/${_players.length} players picked',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.vt323(
                                            fontSize: isPhone ? 14 : 18,
                                            color: const Color(0xFF5C3D1E),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Back button
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _PixelButton(
                          onTap: () => Navigator.of(context).pop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'BACK',
                                style: GoogleFonts.vt323(
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Waiting overlay
                      if (_waitingForOthers) _buildWaitingOverlay(),
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
}

// ─────────────────────────────────────────────────────────
// _CharacterCard – displays the complete Character Sheet (with LEVEL UP badges)
// ─────────────────────────────────────────────────────────
class _CharacterCard extends StatefulWidget {
  final CharacterOption character;
  final VoidCallback? onTap;
  final RoomPlayer? takenBy;
  final double cardWidth;
  final double cardHeight;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.cardWidth,
    required this.cardHeight,
    this.takenBy,
  });

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _pressed = false;
  bool _hovered = false;

  String _getCharacterSheetPath(String title) {
    return 'assets/character_sheet/Character Sheet-$title.png';
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    final isTaken = widget.takenBy != null;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) {
        if (!isDisabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!isDisabled) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.60 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : (_hovered ? 1.03 : 1.0),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: _buildSheetCard(isTaken),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetCard(bool isTaken) {
    final sheetPath = _getCharacterSheetPath(widget.character.title);

    return Container(
      width: widget.cardWidth,
      height: widget.cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _hovered
              ? widget.character.accentColor
              : const Color(0xFFD4D4D4),
          width: _hovered ? 3.0 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _hovered
                ? widget.character.accentColor.withOpacity(0.35)
                : Colors.black.withOpacity(0.18),
            offset: const Offset(2, 4),
            blurRadius: _hovered ? 8 : 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(2.5),
              child: Image.asset(
                sheetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    widget.character.assetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  );
                },
              ),
            ),
            if (isTaken) _buildTakenOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTakenOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.takenBy != null) ...[
                Container(
                  width: (widget.cardHeight * 0.32).clamp(24.0, 36.0),
                  height: (widget.cardHeight * 0.32).clamp(24.0, 36.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: widget.takenBy!.avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(widget.takenBy!.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.white24,
                  ),
                  child: widget.takenBy!.avatarUrl == null
                      ? const Icon(Icons.person,
                          color: Colors.white70, size: 18)
                      : null,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.takenBy!.playerName,
                  style: GoogleFonts.vt323(
                    fontSize: (widget.cardHeight * 0.16).clamp(11.0, 15.0),
                    color: Colors.white,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  'TAKEN',
                  style: GoogleFonts.vt323(
                    fontSize: (widget.cardHeight * 0.18).clamp(12.0, 16.0),
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// _FloatingDecor – animated floating decorative pixel-art
// ─────────────────────────────────────────────────────────
class _FloatingDecor extends StatelessWidget {
  final Animation<double> animation;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double floatAmount;
  final Widget child;

  const _FloatingDecor({
    required this.animation,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.floatAmount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, floatAmount * animation.value),
              child: child,
            );
          },
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// _PixelButton – retro pixel-art style button
// ─────────────────────────────────────────────────────────
class _PixelButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PixelButton({required this.onTap, required this.child});

  @override
  State<_PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<_PixelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: _pressed
              ? Matrix4.translationValues(2, 2, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF5C3D1E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF111111), width: 2),
            boxShadow: _pressed
                ? []
                : const [
                    BoxShadow(
                      color: Color(0xFF111111),
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    )
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}