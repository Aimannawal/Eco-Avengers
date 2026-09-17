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

  String _getChibiProfilePath(String title) {
    return 'assets/vector/$title Profile.png';
  }

  // ─────────────────────────────────────────────────────────
  // PHONE: vertically scrollable list of horizontal cards
  // ─────────────────────────────────────────────────────────
  Widget _buildPhoneLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.characters.length; i++) ...[
              _CharacterCard(
                character: widget.characters[i],
                onTap: (_characterSelected ||
                        _isCharacterTaken(widget.characters[i].title))
                    ? null
                    : () => _select(widget.characters[i]),
                profileAsset: _getChibiProfilePath(widget.characters[i].title),
                takenBy: _getTakenByPlayer(widget.characters[i].title),
                isWide: false,
              ),
              if (i != widget.characters.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  // TABLET / DESKTOP: centered wrapping row of cards
  Widget _buildWideLayout({required bool isWide}) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: isWide ? (3 * 200 + 2 * 20 + 2) : double.infinity, // Force wrap at 3 cards
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: isWide ? 20 : 12,
            runSpacing: isWide ? 20 : 12,
            children: [
              for (int i = 0; i < widget.characters.length; i++)
                _CharacterCard(
                  character: widget.characters[i],
                  onTap: (_characterSelected ||
                          _isCharacterTaken(widget.characters[i].title))
                      ? null
                      : () => _select(widget.characters[i]),
                  profileAsset: _getChibiProfilePath(widget.characters[i].title),
                  takenBy: _getTakenByPlayer(widget.characters[i].title),
                  isWide: isWide,
                ),
            ],
          ),
        ),
      ),
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
                                    top: isPhone ? 60 : 90,
                                    bottom: isPhone ? 20 : 30,
                                    left: isPhone ? 10 : 20,
                                    right: isPhone ? 10 : 20,
                                  ),
                                  child: isPhone ? _buildPhoneLayout() : _buildWideLayout(isWide: isWide),
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
// _CharacterCard – parchment-styled selectable card
// ─────────────────────────────────────────────────────────
class _CharacterCard extends StatefulWidget {
  final CharacterOption character;
  final VoidCallback? onTap;
  final String profileAsset;
  final RoomPlayer? takenBy;
  final bool isWide;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.profileAsset,
    required this.isWide,
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
    final isTaken = widget.takenBy != null;
    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.65 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: _buildPrototypeCard(isTaken),
          ),
        ),
      ),
    );
  }

  Widget _buildPrototypeCard(bool isTaken) {
    return Container(
      width: widget.isWide ? 200 : 150,
      height: widget.isWide ? 280 : 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4D4D4), width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(2, 4), blurRadius: 4),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.character.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontSize: widget.isWide ? 14 : 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E86AB),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Image Box
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.character.accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        widget.profileAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (isTaken) _buildTakenOverlay(isSmall: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Description
            SizedBox(
              height: widget.isWide ? 44 : 36,
              child: Center(
                child: Text(
                  widget.character.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: widget.isWide ? 10 : 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakenOverlay({required bool isSmall}) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.60),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.takenBy != null) ...[
                Container(
                  width: isSmall ? 32 : 44,
                  height: isSmall ? 32 : 44,
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
                      ? Icon(Icons.person,
                          color: Colors.white70, size: isSmall ? 16 : 22)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.takenBy!.playerName,
                  style: GoogleFonts.vt323(
                      fontSize: isSmall ? 12 : 14,
                      color: Colors.white,
                      height: 1),
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
                      fontSize: isSmall ? 13 : 16,
                      color: Colors.white,
                      letterSpacing: 1),
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