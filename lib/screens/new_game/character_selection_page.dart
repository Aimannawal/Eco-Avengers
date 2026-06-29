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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  static const Color _borderColor = Color(0xFF111111);
  static const Color _feltColor = Color(0xFF6A9073);

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    if (_isMultiplayer) {
      _subscribeToPlayers();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
        gameState = await GameStateService.instance.initGameState(
          roomId: roomId,
          hostPlayerId: myPlayerId,
          difficulty: widget.difficulty,
          playerOrder: players.map((p) => p.playerId).toList(),
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
          SnackBar(content: Text('Gagal pilih karakter: $e')),
        );
      }
    }
  }

  String _getChibiProfilePath(String title) {
    return 'assets/vector/$title Profile.png';
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
          Container(color: Colors.black.withOpacity(0.12)),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactHeight = constraints.maxHeight < 500;
                  final isWide = constraints.maxWidth >= 760;
                  
                  final boardWidth = isWide
                      ? math.min(constraints.maxWidth * 0.96, 1140.0)
                      : constraints.maxWidth * 0.94;
                  final boardHeight = math.min(constraints.maxHeight * 0.94, 580.0);

                  final cardWidth = isCompactHeight ? 100.0 : (isWide ? 190.0 : 140.0);
                  final cardHeight = isCompactHeight ? 180.0 : (isWide ? 340.0 : 250.0);
                  final gap = isCompactHeight ? 8.0 : (isWide ? 16.0 : 10.0);

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Top-Left: Scattered cards
                      Positioned(
                        left: isWide ? constraints.maxWidth * 0.01 : 10,
                        top: isWide ? constraints.maxHeight * 0.02 : 10,
                        child: Transform.rotate(
                          angle: -0.25,
                          child: SizedBox(
                            width: isWide ? 90 : 70,
                            height: isWide ? 130 : 100,
                            child: Image.asset(
                              'assets/action_card/Action Cards-Back.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // Scattered Tokens
                      Positioned(
                        right: isWide ? constraints.maxWidth * 0.04 : 40,
                        bottom: isWide ? constraints.maxHeight * 0.02 : 5,
                        child: Transform.rotate(
                          angle: -0.15,
                          child: SizedBox(
                            width: isWide ? 44 : 32,
                            height: isWide ? 44 : 32,
                            child: Image.asset(
                              'assets/token/sustainable.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: isWide ? constraints.maxWidth * 0.06 : 40,
                        top: isWide ? constraints.maxHeight * 0.01 : 5,
                        child: Transform.rotate(
                          angle: 0.3,
                          child: SizedBox(
                            width: isWide ? 40 : 30,
                            height: isWide ? 40 : 30,
                            child: Image.asset(
                              'assets/token/crisis.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      
                      // MAIN GREEN FELT BOARD
                      Center(
                        child: SizedBox(
                          width: boardWidth,
                          height: boardHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Felt board panel
                              Container(
                                decoration: BoxDecoration(
                                  color: _feltColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _borderColor,
                                    width: 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                child: Column(
                                  children: [
                                    // Title
                                    Text(
                                      'SELECT YOUR CHARACTER',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.montserrat(
                                        fontSize: isWide ? 28 : 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2.0,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Multiplayer: ready count
                                    if (_isMultiplayer) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_players.where((p) => p.isReady).length}/${_players.length} pemain sudah pilih karakter',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: isWide ? 24 : 16),
                                    // Character Cards
                                    Expanded(
                                      child: Center(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                for (int i = 0; i < widget.characters.length; i++) ...[
                                                  _CharacterCard(
                                                    character: widget.characters[i],
                                                    onTap: _characterSelected
                                                        ? null
                                                        : () => _select(widget.characters[i]),
                                                    width: cardWidth,
                                                    height: cardHeight,
                                                    isWide: isWide,
                                                    profileAsset: _getChibiProfilePath(widget.characters[i].title),
                                                  ),
                                                  if (i != widget.characters.length - 1)
                                                    SizedBox(width: gap),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Waiting overlay (multiplayer)
                              if (_waitingForOthers)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.60),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(
                                              color: Color(0xFFA5C18A),
                                              strokeWidth: 3,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Karakter dipilih! ✓',
                                              style: GoogleFonts.montserrat(
                                                fontSize: isWide ? 20 : 16,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFA5C18A),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Menunggu pemain lain...',
                                              style: GoogleFonts.montserrat(
                                                fontSize: isWide ? 14 : 12,
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              '${_players.where((p) => p.isReady).length}/${_players.length} siap',
                                              style: GoogleFonts.montserrat(
                                                fontSize: isWide ? 16 : 13,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Back Button
                              Positioned(
                                left: -14,
                                top: -14,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(),
                                    borderRadius: BorderRadius.circular(100),
                                    child: Container(
                                      width: isWide ? 64 : 52,
                                      height: isWide ? 64 : 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _feltColor,
                                        border: Border.all(
                                          color: _borderColor,
                                          width: 3.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: isWide ? 32 : 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

class _CharacterCard extends StatefulWidget {
  final CharacterOption character;
  final VoidCallback? onTap; // nullable = disabled
  final double width;
  final double height;
  final bool isWide;
  final String profileAsset;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.width,
    required this.height,
    required this.isWide,
    required this.profileAsset,
  });

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF111111), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Header (Title)
                Container(
                  height: widget.isWide ? 50 : 40,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(bottom: BorderSide(color: Color(0xFF111111), width: 3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  child: Text(
                    widget.character.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: widget.character.accentColor,
                      fontSize: widget.isWide ? 12.0 : 10.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // 2. Chibi profile section
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF2AA5B2),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          widget.profileAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, color: Colors.white);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // Border divider
                Container(height: 3, color: const Color(0xFF111111)),
                // 3. Description
                Container(
                  height: widget.isWide ? 116 : 80,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    widget.character.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: widget.isWide ? 12.0 : 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}