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
                  final isPhonePortrait = !isWide && !isCompactHeight;
                  
                  final boardWidth = isWide
                      ? math.min(constraints.maxWidth * 0.96, 1140.0)
                      : constraints.maxWidth * 0.96;
                  final boardHeight = math.min(constraints.maxHeight * 0.94, isPhonePortrait ? 640.0 : 580.0);

                  final cardWidth = isCompactHeight ? 130.0 : (isWide ? 190.0 : 200.0);
                  final cardHeight = isCompactHeight ? 230.0 : (isWide ? 340.0 : 370.0);
                  final gap = isCompactHeight ? 12.0 : (isWide ? 16.0 : 14.0);

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
                                                    onTap: (_characterSelected || _isCharacterTaken(widget.characters[i].title))
                                                        ? null
                                                        : () => _select(widget.characters[i]),
                                                    width: cardWidth,
                                                    height: cardHeight,
                                                    isWide: isWide,
                                                    isPhone: isPhonePortrait,
                                                    profileAsset: _getChibiProfilePath(widget.characters[i].title),
                                                    takenBy: _getTakenByPlayer(widget.characters[i].title),
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
  final bool isPhone;
  final String profileAsset;
  final RoomPlayer? takenBy;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.width,
    required this.height,
    required this.isWide,
    this.isPhone = false,
    required this.profileAsset,
    this.takenBy,
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
                  height: widget.isWide ? 50 : (widget.isPhone ? 36 : 24),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(bottom: BorderSide(color: Color(0xFF111111), width: 3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  child: Text(
                    widget.character.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: widget.character.accentColor,
                      fontSize: widget.isWide ? 12.0 : (widget.isPhone ? 9.0 : 6.5),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                ),
                // 2. Chibi profile section
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF2AA5B2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              widget.profileAsset,
                              fit: BoxFit.fitHeight,
                              height: double.infinity,
                              cacheHeight: 512,
                              cacheWidth: 512,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white70,
                                    size: 40,
                                  ),
                                );
                              },
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedOpacity(
                                  opacity: frame != null ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 500),
                                  child: child,
                                );
                              },
                            ),
                          ),
                        ),
                        // Taken overlay
                        if (widget.takenBy != null)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.55),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Player avatar (account profile pic)
                                    Container(
                                      width: widget.isWide ? 48 : (widget.isPhone ? 40 : 32),
                                      height: widget.isWide ? 48 : (widget.isPhone ? 40 : 32),
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
                                          ? const Icon(Icons.person, color: Colors.white70, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.takenBy!.playerName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: widget.isWide ? 12 : (widget.isPhone ? 10 : 8),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'TAKEN',
                                        style: GoogleFonts.montserrat(
                                          fontSize: widget.isWide ? 9 : (widget.isPhone ? 8 : 6),
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Border divider
                Container(height: 3, color: const Color(0xFF111111)),
                // 3. Description
                Container(
                  height: widget.isWide ? 116 : (widget.isPhone ? 72 : 48),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    widget.character.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: widget.isWide ? 12.0 : (widget.isPhone ? 9.0 : 7.0),
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