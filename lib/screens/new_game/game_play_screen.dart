import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/game_models.dart';
import '../../models/room_model.dart';
import '../../services/game_state_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background_decoration.dart';
import 'character_selection_page.dart';
import 'character_sheet_dialog.dart';
import 'interactive_map_dialog.dart';
import 'spin_wheel_dialog.dart';

class GamePlayScreen extends StatefulWidget {
  final String selectedCharacterId;
  final String selectedCharacterName;
  final String selectedDifficulty;
  final Color characterAccentColor;
  final String? characterAssetPath;
  final String selectedRegion;

  // Multiplayer params (null = single player)
  final String? multiplayerRoomId;
  final MultiplayerGameState? multiplayerGameState;
  final List<RoomPlayer>? multiplayerPlayers;
  final String? myPlayerId;

  const GamePlayScreen({
    Key? key,
    required this.selectedCharacterId,
    required this.selectedCharacterName,
    required this.selectedDifficulty,
    required this.characterAccentColor,
    this.characterAssetPath,
    required this.selectedRegion,
    this.multiplayerRoomId,
    this.multiplayerGameState,
    this.multiplayerPlayers,
    this.myPlayerId,
  }) : super(key: key);

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with TickerProviderStateMixin {
  static const Color _buttonGreen = Color(0xFFA5C18A);
  static const Color _buttonBorder = Color(0xFF111111);
  static const String _leftSidebarAssetPath =
      'assets/eco_crisis_card/Eco Crisis Card-Africa-Back.png';
  static const String _mapPopupAssetPath = 'assets/background/map.png';
  static const String _planetaryCrisisTokenAssetPath =
      'assets/token/crisis.png';
  static const String _peaceTokenAssetPath = 'assets/token/sustainable.png';
  static const List<String> _actionCardAssets = [
    'assets/action_card/1.png',
    'assets/action_card/2.png',
    'assets/action_card/3.png',
    'assets/action_card/4.png',
    'assets/action_card/5.png',
    'assets/action_card/6.png',
    'assets/action_card/7.png',
    'assets/action_card/8.png',
    'assets/action_card/9.png',
    'assets/action_card/10.png',
  ];

  late final GameRound gameRound;
  late final AnimationController _fadeController;
  late final List<CharacterOption> characters;
  late final List<String> _displayedActionCards;
  late int _crisisTokenPosition = 0;
  late int _sustainableTokenPosition = 4;
  bool _showResultFeedback = false;
  CharacterOption? selectedCharacter;

  // ── Multiplayer state ─────────────────────────────────────
  bool _isMultiplayer = false;
  MultiplayerGameState? _mpGameState;
  List<RoomPlayer> _mpPlayers = [];
  String _myPlayerId = '';
  bool _isMyTurn = false;
  RealtimeChannel? _gameStateChannel;

  String _boardCharacterAssetPath(String characterName) {
    return 'assets/vector/$characterName Profile.png';
  }

  String _getEcoCrisisCardPath() {
    final level = gameRound.currentEcoCrisisLevel;
    final variant = gameRound.currentEcoCrisisVariant;
    final region = gameRound.selectedRegion;
    // Format: assets/eco_crisis_card/Eco Crisis Card-{Region}-Back/{Level} - {Variant}.png
    final path =
        'assets/eco_crisis_card/Eco Crisis Card-$region-Back/$level - $variant.png';
    return path;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    characters = const [
      CharacterOption(
        title: 'Environmental Activist',
        description: 'Move two spaces forward at once during your turn.',
        assetPath: 'assets/vector/Environmental Activist Profile.png',
        accentColor: Color(0xFF38A3A5),
      ),
      CharacterOption(
        title: 'Policymaker',
        description:
            'Adds 1 to the first derived dice value for other players in range.',
        assetPath: 'assets/vector/Policymaker Profile.png',
        accentColor: Color(0xFFB07D54),
      ),
      CharacterOption(
        title: 'Climate Engineer',
        description: 'Decreases Climate Resilience difficulty by 1.',
        assetPath: 'assets/vector/Climate Engineer Profile.png',
        accentColor: Color(0xFFF06292),
      ),
      CharacterOption(
        title: 'Ecologist',
        description: 'Decreases Environmental Degradation difficulty by 1.',
        assetPath: 'assets/vector/Ecologist Profile.png',
        accentColor: Color(0xFFED9B3B),
      ),
      CharacterOption(
        title: 'Energy Scientist',
        description: 'Decreases Energy Crisis difficulty by 1.',
        assetPath: 'assets/vector/Energy Scientist Profile.png',
        accentColor: Color(0xFF4F7DBA),
      ),
    ];

    try {
      selectedCharacter = characters.firstWhere(
        (c) => c.title == widget.selectedCharacterName,
      );
    } catch (_) {
      selectedCharacter = characters.first;
    }

    gameRound = GameRound(
      roundNumber: 1,
      selectedCharacterId: widget.selectedCharacterId,
      selectedDifficulty: widget.selectedDifficulty,
    );

    gameRound.setRegion(widget.selectedRegion);
    _crisisTokenPosition = 0;
    _sustainableTokenPosition = 4;

    _displayedActionCards = _pickRandomActionCards();
    // Deal the picked cards into the player's hand
    for (final card in _displayedActionCards) {
      gameRound.handCards.add(card);
    }
    _fadeController.forward();

    // Multiplayer init
    _isMultiplayer = widget.multiplayerRoomId != null;
    if (_isMultiplayer) {
      _mpGameState = widget.multiplayerGameState;
      _mpPlayers = widget.multiplayerPlayers ?? [];
      _initMultiplayer();
    } else {
      // Single player: show map immediately for region selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMapPopup();
      });
    }
  }

  Future<void> _initMultiplayer() async {
    _myPlayerId = await SupabaseService.instance.getOrCreatePlayerId();
    _updateTurnState();
    _gameStateChannel = GameStateService.instance.streamGameState(
      roomId: widget.multiplayerRoomId!,
      onUpdate: _onGameStateUpdated,
    );
  }

  void _onGameStateUpdated(MultiplayerGameState state) {
    if (!mounted) return;
    setState(() {
      _mpGameState = state;
      // Sync local gameRound tokens with multiplayer state
      gameRound.energy = state.energy;
      gameRound.peace = state.peace;
      gameRound.crisisTokens = state.crisisTokens;
      gameRound.currentEcoCrisisLevel = state.ecoCrisisLevel;
      gameRound.selectedRegion = state.selectedRegion;
    });
    _updateTurnState();
  }

  void _updateTurnState() {
    if (_mpGameState == null) return;
    final newIsMyTurn = _mpGameState!.currentPlayerId == _myPlayerId;
    if (newIsMyTurn != _isMyTurn) {
      setState(() => _isMyTurn = newIsMyTurn);
      if (newIsMyTurn && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎯 Giliran kamu!',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Sync perubahan token ke Supabase (hanya saat multiplayer & giliran saya)
  Future<void> _syncToSupabase() async {
    if (!_isMultiplayer || !_isMyTurn) return;
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      energy: gameRound.energy,
      peace: gameRound.peace,
      crisisTokens: gameRound.crisisTokens,
      ecoCrisisLevel: gameRound.currentEcoCrisisLevel,
      selectedRegion: gameRound.selectedRegion,
    );
  }

  List<String> _pickRandomActionCards() {
    final cards = List<String>.from(_actionCardAssets);
    cards.shuffle(math.Random());
    return cards.take(3).toList();
  }

  @override
  void dispose() {
    _gameStateChannel?.unsubscribe();
    _fadeController.dispose();
    super.dispose();
  }

  /// Maps a specific card (Region, Level, Variant) to the badge type it awards on WIN.
  String _getBadgeTypeForCard(String region, int level, int variant) {
    final cardId = '$level - $variant';

    switch (region) {
      case 'Africa':
        if (const ['3 - 1', '4 - 1', '4 - 2'].contains(cardId))
          return 'climate';
        if (const ['4 - 3', '4 - 4', '5 - 1'].contains(cardId)) return 'energy';
        if (const ['3 - 2', '4 - 5', '5 - 2'].contains(cardId))
          return 'ecology';
        break;
      case 'Asia':
        if (const ['3 - 1', '4 - 1', '5 - 1'].contains(cardId))
          return 'climate';
        if (const ['4 - 2', '4 - 3', '5 - 2'].contains(cardId)) return 'energy';
        if (const ['3 - 2', '4 - 4', '4 - 5'].contains(cardId))
          return 'ecology';
        break;
      case 'Central & South America':
        if (const ['3 - 1', '4 - 1', '4 - 2'].contains(cardId))
          return 'climate';
        if (const ['3 - 2', '4 - 3', '4 - 4'].contains(cardId)) return 'energy';
        if (const ['3 - 3', '4 - 5', '5 - 1'].contains(cardId))
          return 'ecology';
        break;
      case 'Europe':
        if (const ['3 - 1', '4 - 1', '5 - 1'].contains(cardId))
          return 'climate';
        if (const ['3 - 2', '4 - 2', '5 - 2'].contains(cardId)) return 'energy';
        if (const ['3 - 3', '4 - 3', '4 - 4'].contains(cardId))
          return 'ecology';
        break;
      case 'North America':
        if (const ['3 - 1', '4 - 1', '5 - 1'].contains(cardId))
          return 'climate';
        if (const ['3 - 2', '4 - 2', '4 - 3'].contains(cardId)) return 'energy';
        if (const ['3 - 3', '4 - 5', '4 - 4'].contains(cardId))
          return 'ecology';
        break;
    }

    // Default fallback
    return 'climate';
  }

  void _showCharacterSheet(CharacterOption character) {
    showDialog<void>(
      context: context,
      builder: (context) => CharacterSheetDialog(
        characterName: character.title,
        assetPath: character.assetPath,
        accentColor: character.accentColor,
        ability: character.description,
        unlockedBadgeLevels: Map<String, int>.from(
          gameRound.unlockedBadgeLevels,
        ),
      ),
    );
  }

  void _showSpinWheel() {
    showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SpinWheelDialog(
        difficulty: widget.selectedDifficulty,
        onResult: _handleSpinResult,
      ),
    );
  }

  // ── Card helpers ────────────────────────────────────────────────────────────

  /// Extracts the card number from an asset path like 'assets/action_card/3.png' → 3.
  int _cardNumber(String path) {
    final filename = path.split('/').last.replaceAll('.png', '');
    return int.tryParse(filename) ?? 0;
  }

  bool _hasCard(int number) =>
      gameRound.handCards.any((p) => _cardNumber(p) == number);

  String? _cardPath(int number) {
    try {
      return gameRound.handCards.firstWhere((p) => _cardNumber(p) == number);
    } catch (_) {
      return null;
    }
  }

  /// Whether a card can be used right now given the current game state.
  bool _isCardUsable(int number) {
    switch (number) {
      case 1:
        return (gameRound.currentEcoCrisisLevel -
                gameRound.difficultyReduction) >
            1;
      case 2:
        return _crisisTokenPosition > 0;
      case 3:
        return true; // always usable when held
      case 4:
        return _crisisTokenPosition > 0;
      case 5:
        return true; // auto-win always possible
      case 6:
        return true; // passive – shown here as always
      case 7:
        return !gameRound.anyNumberWins;
      case 8: // climate
        return _getBadgeTypeForCard(
                  gameRound.selectedRegion,
                  gameRound.currentEcoCrisisLevel,
                  gameRound.currentEcoCrisisVariant,
                ) ==
                'climate' &&
            (gameRound.currentEcoCrisisLevel - gameRound.difficultyReduction) >
                1;
      case 9: // ecology
        return _getBadgeTypeForCard(
                  gameRound.selectedRegion,
                  gameRound.currentEcoCrisisLevel,
                  gameRound.currentEcoCrisisVariant,
                ) ==
                'ecology' &&
            (gameRound.currentEcoCrisisLevel - gameRound.difficultyReduction) >
                1;
      case 10: // energy
        return _getBadgeTypeForCard(
                  gameRound.selectedRegion,
                  gameRound.currentEcoCrisisLevel,
                  gameRound.currentEcoCrisisVariant,
                ) ==
                'energy' &&
            (gameRound.currentEcoCrisisLevel - gameRound.difficultyReduction) >
                1;
      default:
        return false;
    }
  }

  String _cardDescription(int number) {
    switch (number) {
      case 1:
        return 'Reduce crisis level by 1 for the next spin';
      case 2:
        return 'Move the Planet Crisis token back 1 space';
      case 3:
        return 'Move to a different region on the map';
      case 4:
        return 'Move the Planet Crisis token back 1 space';
      case 5:
        return 'Instantly win the current Eco Crisis!';
      case 6:
        return 'Ignore this fail and re-spin once';
      case 7:
        return 'Any number wins — only FAIL loses — next spin';
      case 8:
        return 'Reduce the Climate crisis level by 1';
      case 9:
        return 'Reduce the Ecology crisis level by 1';
      case 10:
        return 'Reduce the Energy crisis level by 1';
      default:
        return 'Use this card';
    }
  }

  void _useCard(String path) {
    final number = _cardNumber(path);
    if (!_isCardUsable(number)) return;

    // Show confirmation dialog
    showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFA5C18A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(path, width: 220, fit: BoxFit.contain),
                ),
                const SizedBox(height: 14),
                Text(
                  _cardDescription(number),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF111111),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA5C18A),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(
                            color: Color(0xFF111111),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Text(
                          'Use Card',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((confirmed) {
      if (confirmed != true) return;
      _applyCardEffect(path, number);
    });
  }

  void _applyCardEffect(String path, int number) {
    gameRound.useCard(path);
    setState(() {});

    switch (number) {
      case 1:
        // Buff: decrease target spin value
        setState(() => gameRound.difficultyReduction += 1);
        _showCardSnack('Difficulty reduced by 1 for next spin ✨');
        break;

      case 2:
      case 4:
        setState(() {
          _crisisTokenPosition = (_crisisTokenPosition - 1).clamp(0, 13);
        });
        _showCardSnack('Planet Crisis retreated 1 space 🔙');
        break;

      case 3:
        // Open map freely when this card is used
        _showMapPopupWithCard();
        break;

      case 5:
        // Auto-WIN the current crisis
        _handleSpinResult(gameRound.currentEcoCrisisLevel.toString());
        _showCardSnack('Auto-Win triggered! 🌟');
        break;

      case 6:
        // Passive — handled in _handleSpinResult when fail occurs
        _showCardSnack(
          'Reroll card is now active 🎲 It will trigger on next FAIL',
        );
        // Card is already removed from hand by useCard(), put it back as a pending buff
        gameRound.handCards.add(path); // re-add temporarily as "pending"
        gameRound.usedCards.removeLast();
        setState(() {});
        break;

      case 7:
        setState(() => gameRound.anyNumberWins = true);
        _showCardSnack('Any number wins for next spin! 🎯');
        break;

      case 8:
      case 9:
      case 10:
        setState(() {
          gameRound.difficultyReduction += 1;
        });
        _showCardSnack('Crisis level reduced by 1 📉');
        break;
    }
  }

  void _showCardSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Draw 1 random Action Card and add it to the player's hand.
  void _drawRandomCard({VoidCallback? onDone}) {
    if (!mounted) {
      if (onDone != null) onDone();
      return;
    }
    final picked =
        _actionCardAssets[math.Random().nextInt(_actionCardAssets.length)];
    setState(() => gameRound.handCards.add(picked));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        // Auto-close after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'New Card!',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      const Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(picked, width: 200, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (onDone != null) onDone();
    });
  }

  // ── Map popup with card 3 requirement ───────────────────────────────────────

  void _showMapPopupWithCard() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return InteractiveMapDialog(
          characterName: widget.selectedCharacterName,
          characterAccentColor: widget.characterAccentColor,
          initialRegion: gameRound.selectedRegion,
          onRegionSelected: (selectedRegion) {
            setState(() {
              gameRound.setRegion(selectedRegion);
            });
          },
        );
      },
    );
  }

  void _handleMapButtonTap() {
    if (_hasCard(3)) {
      // Has card 3 — open map with full region-change ability
      _showMapPopupWithCard();
    } else {
      // No card 3 — still open map for viewing, but block region change
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (dialogContext) {
          return InteractiveMapDialog(
            characterName: widget.selectedCharacterName,
            characterAccentColor: widget.characterAccentColor,
            initialRegion: gameRound.selectedRegion,
            onRegionSelected: (selectedRegion) {
              // Cannot change region without Card 3
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Text('🔒 ', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Need Action Card #3 to change region!',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFB71C1C),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  // ── Spin result with buff/card 6 support ────────────────────────────────────

  void _handleSpinResult(String result) {
    final currentLevel = gameRound.currentEcoCrisisLevel;
    final currentVariant = gameRound.currentEcoCrisisVariant;
    // Apply Card 1 buff: treat level as lower (can stack)
    final effectiveLevel = (currentLevel - gameRound.difficultyReduction).clamp(
      1,
      99,
    );

    if (gameRound.difficultyReduction > 0) {
      setState(() => gameRound.difficultyReduction = 0);
    }

    final resultLevel = int.tryParse(result) ?? 0;

    // Card 7 buff: any number wins
    final bool anyWins = gameRound.anyNumberWins;
    if (anyWins) setState(() => gameRound.anyNumberWins = false);

    // Debug output
    print('=== SPIN RESULT ===');
    print('Current Level: $currentLevel (effective: $effectiveLevel)');
    print('Spin Result: $result (parsed: $resultLevel)');
    print('Is Fail: ${result == "fail"}');
    print('Eco Crisis Card Path: ${_getEcoCrisisCardPath()}');

    if (result == 'fail') {
      // Direct FAIL from wheel — check for Card 6 reroll first
      if (_hasCard(6)) {
        _promptCard6Reroll();
        return;
      }
      print('Result: FAIL (from wheel)');
      setState(() {
        _crisisTokenPosition = (_crisisTokenPosition + 1).clamp(0, 13);
        gameRound.failCount++;
        _showResultFeedback = true;
        gameRound.randomizeEcoCrisisLevel();
      });

      // Force card refresh
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) setState(() {});
      });

      // Check if crisis token reached the end (game over - player loses)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_crisisTokenPosition >= 13) {
          _showGameOverDialog(playerWon: false);
        }
      });

      _showGameResultDialog(
        title: 'FAIL',
        message: 'Planetary Crisis advances!',
        isSuccess: false,
        onClosed: () => _drawRandomCard(),
      );
      // Auto-clear feedback after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showResultFeedback = false);
        }
      });
    } else {
      // Check if numeric result >= effectiveLevel for WIN (Card 1 may lower it)
      print(
        'Comparing: $resultLevel >= $effectiveLevel = ${resultLevel >= effectiveLevel} | anyWins: $anyWins',
      );

      if (anyWins ? result != 'fail' : resultLevel >= effectiveLevel) {
        // WIN
        print('Result: WIN');

        // Unlock badge based on the exact card played
        final badgeType = _getBadgeTypeForCard(
          gameRound.selectedRegion,
          currentLevel,
          currentVariant,
        );
        final badgeUnlocked = gameRound.unlockBadge(badgeType);

        setState(() {
          _sustainableTokenPosition = (_sustainableTokenPosition + 1).clamp(
            0,
            13,
          );
          gameRound.successCount++;
          _showResultFeedback = true;
          // User asked for this logic
          gameRound.randomizeEcoCrisisLevel();
        });

        // Show badge unlock notification
        if (badgeUnlocked && mounted) {
          final newLevel = gameRound.getBadgeLevel(badgeType);
          final badgeLabel = badgeType == 'energy'
              ? 'Energy Science'
              : badgeType == 'ecology'
              ? 'Environmental Ecology'
              : 'Climate Engineering';
          final levelLabel = newLevel == 3 ? 'Master Token' : 'Level $newLevel';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🏅 ', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Badge Unlocked! $badgeLabel — $levelLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        // Force card refresh
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() {});
        });

        // Check if sustainable token reached the end (won the game)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_sustainableTokenPosition >= 13) {
            _showGameOverDialog(playerWon: true);
          }
        });

        _showGameResultDialog(
          title: 'WIN',
          message: 'Sustainability advances! 🌱',
          isSuccess: true,
          onClosed: () {
            // Draw 1 card as reward, then show character sheet
            _drawRandomCard(
              onDone: () {
                if (mounted && selectedCharacter != null) {
                  _showCharacterSheet(selectedCharacter!);
                }
              },
            );
          },
        );

        // Auto-clear feedback after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _showResultFeedback = false);
          }
        });
      } else {
        // FAILED (result < level) — check for Card 6 reroll first
        if (_hasCard(6)) {
          _promptCard6Reroll();
          return;
        }
        print('Result: FAILED');
        setState(() {
          _crisisTokenPosition = (_crisisTokenPosition + 1).clamp(0, 13);
          gameRound.failCount++;
          _showResultFeedback = true;
          gameRound.randomizeEcoCrisisLevel();
        });

        // Force card refresh
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() {});
        });

        // Check if crisis token reached the end (game over - player loses)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_crisisTokenPosition >= 13) {
            _showGameOverDialog(playerWon: false);
          }
        });

        _showGameResultDialog(
          title: 'FAILED',
          message: 'Planetary Crisis advances!',
          isSuccess: false,
          onClosed: () => _drawRandomCard(),
        );
        // Auto-clear feedback after 1.5 seconds
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _showResultFeedback = false);
          }
        });
      }
    }
    print('==================');
  }

  void _promptCard6Reroll() {
    final card6Path = _cardPath(6)!;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEB5757), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    card6Path,
                    width: 130,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You got FAIL! Use Action Card #6 to re-spin?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF111111),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'No, Fail',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA5C18A),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(
                            color: Color(0xFF111111),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Text(
                          'Reroll! 🎲',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((useCard) {
      if (useCard == true) {
        // Consume card 6 and reopen spin wheel
        gameRound.useCard(card6Path);
        setState(() {});
        _showSpinWheel();
      } else {
        // Accept the FAIL outcome
        final lvl = gameRound.currentEcoCrisisLevel;
        setState(() {
          _crisisTokenPosition = (_crisisTokenPosition + 1).clamp(0, 13);
          gameRound.failCount++;
          _showResultFeedback = true;
          gameRound.randomizeEcoCrisisLevel();
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_crisisTokenPosition >= 13) _showGameOverDialog(playerWon: false);
        });
        _showGameResultDialog(
          title: 'FAIL',
          message: 'Planetary Crisis advances!',
          isSuccess: false,
          onClosed: () => _drawRandomCard(),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showResultFeedback = false);
        });
      }
    });
  }

  void _showGameOverDialog({required bool playerWon}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: playerWon
                    ? const Color(0xFFA5C18A)
                    : const Color(0xFFEB5757),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GAME OVER',
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  playerWon ? 'YOU WIN!' : 'YOU LOSE!',
                  style: GoogleFonts.montserrat(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: playerWon
                        ? const Color(0xFFA5C18A)
                        : const Color(0xFFEB5757),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  playerWon
                      ? 'Sustainability reached the goal! 🌱'
                      : 'Planetary Crisis reached the goal! 🌍',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to the very first route (HomeScreen)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: playerWon
                          ? const Color(0xFFA5C18A)
                          : const Color(0xFFEB5757),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(51),
                        side: const BorderSide(
                          color: Color(0xFF111111),
                          width: 3,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Back to Menu',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGameResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onClosed, // called when user taps Continue
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSuccess
                    ? const Color(0xFFA5C18A)
                    : const Color(0xFFEB5757),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isSuccess
                        ? const Color(0xFFA5C18A)
                        : const Color(0xFFEB5757),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClosed?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess
                          ? const Color(0xFFA5C18A)
                          : const Color(0xFFEB5757),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(51),
                        side: const BorderSide(
                          color: Color(0xFF111111),
                          width: 3,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPhotoPopup() {
    _showImagePopup(_getEcoCrisisCardPath());
  }

  void _showMapPopup() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return InteractiveMapDialog(
          characterName: widget.selectedCharacterName,
          characterAccentColor: widget.characterAccentColor,
          initialRegion: gameRound.selectedRegion,
          onRegionSelected: (selectedRegion) {
            setState(() {
              gameRound.setRegion(selectedRegion);
            });
          },
        );
      },
    );
  }

  void _showImagePopup(String assetPath) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 720,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 360,
                            color: AppColors.softGray.withOpacity(0.15),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: AppColors.pureWhite,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.black87,
                    tooltip: 'Close',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Wood background texture
            Image.asset(
              'assets/background/kayu.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            // 2. White layer container with map board
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 3. Map background image
                      Image.asset(
                        'assets/background/map-boardgame.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                      // 4. Game content overlay
                      SafeArea(
                        child: Row(
                          children: [
                            _buildPhotoDisplay(),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTokenTrack(),
                                  const Expanded(child: SizedBox.expand()),
                                  _buildActionCardsStrip(),
                                ],
                              ),
                            ),
                            _buildCharacterDisplay(),
                          ],
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
    );
  }

  Widget _buildGameStatsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUND ${gameRound.currentRound}',
                style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.selectedDifficulty.toLowerCase() == 'easy'
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : widget.selectedDifficulty.toLowerCase() == 'normal'
                          ? const Color(0xFF2196F3).withOpacity(0.15)
                          : const Color(0xFFF44336).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.selectedDifficulty.toLowerCase() == 'easy'
                        ? const Color(0xFF4CAF50).withOpacity(0.5)
                        : widget.selectedDifficulty.toLowerCase() == 'normal'
                            ? const Color(0xFF2196F3).withOpacity(0.5)
                            : const Color(0xFFF44336).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.selectedDifficulty.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    color: widget.selectedDifficulty.toLowerCase() == 'easy'
                        ? const Color(0xFF2E7D32)
                        : widget.selectedDifficulty.toLowerCase() == 'normal'
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFC62828),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatBadge(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFF4CAF50).withOpacity(0.1),
                  label: 'WIN',
                  value: gameRound.successCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBadge(
                  icon: Icons.highlight_off,
                  color: const Color(0xFFC62828),
                  bgColor: const Color(0xFFF44336).withOpacity(0.1),
                  label: 'LOSE',
                  value: gameRound.failCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.black87,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCardsStrip() {
    final isCompactHeight = MediaQuery.of(context).size.height < 500;
    final cardWidth = isCompactHeight ? 80.0 : 120.0;
    final cardHeight = isCompactHeight ? 112.0 : 168.0;

    final hand = gameRound.handCards;

    if (hand.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          height: isCompactHeight ? 136.0 : 192.0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Center(
            child: Text(
              'No action cards in hand',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final cardWidgets = hand.map((assetPath) {
      final num = _cardNumber(assetPath);
      final usable = _isCardUsable(num);

      return GestureDetector(
        onTap: () => _useCard(assetPath),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(
            right: 12,
            bottom: usable ? 0 : 0,
            top: usable ? 0 : 4,
          ),
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: usable
                ? Border.all(color: const Color(0xFF4CAF50), width: 2.5)
                : Border.all(color: Colors.transparent, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: usable
                    ? const Color(0xFF4CAF50).withOpacity(0.45)
                    : Colors.black.withOpacity(0.18),
                blurRadius: usable ? 14 : 6,
                offset: const Offset(0, 4),
                spreadRadius: usable ? 2 : 0,
              ),
            ],
          ),
          child: Opacity(
            opacity: usable ? 1.0 : 0.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.asset(
                    assetPath,
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.softGray.withOpacity(0.2),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.black54,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  if (usable)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'USE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        height: isCompactHeight ? 136.0 : 192.0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: cardWidgets),
        ),
      ),
    );
  }

  Widget _buildTokenTrack() {
    final isCompactHeight = MediaQuery.of(context).size.height < 500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: isCompactHeight ? 64.0 : 88.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: List.generate(14, (index) {
              final isCrisisPosition = index == _crisisTokenPosition;
              final isSustainablePosition = index == _sustainableTokenPosition;

              String? assetPath;
              if (isCrisisPosition) {
                assetPath = _planetaryCrisisTokenAssetPath;
              } else if (isSustainablePosition) {
                assetPath = _peaceTokenAssetPath;
              }

              // Calculate color based on progress (red to green)
              final progress = index / 13; // 0 to 1
              final hue =
                  (1 - progress) * 0.0 +
                  progress * 0.33; // Red (0) to Green (0.33)
              final tokenColor = HSVColor.fromAHSV(
                1.0,
                hue * 360,
                0.3,
                0.88,
              ).toColor();

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: isCompactHeight ? 42.0 : 58.0,
                  height: isCompactHeight ? 42.0 : 58.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokenColor,
                    border: Border.all(
                      color: isCrisisPosition || isSustainablePosition
                          ? Colors.black.withOpacity(0.25)
                          : Colors.black.withOpacity(0.12),
                      width: isCrisisPosition || isSustainablePosition
                          ? 3
                          : 1.5,
                    ),
                  ),
                  child: assetPath == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: ClipOval(
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                );
                              },
                            ),
                          ),
                        ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoDisplay() {
    final cardPath = _getEcoCrisisCardPath();
    final isCompactHeight = MediaQuery.of(context).size.height < 500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8), // margin kiri-kanan
      child: SizedBox(
        width: isCompactHeight ? 180 : 260,
        child: GestureDetector(
          onTap: _showPhotoPopup,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  cardPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.softGray.withOpacity(0.15),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.black38,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Region: ${gameRound.selectedRegion}\nLevel: ${gameRound.currentEcoCrisisLevel}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (gameRound.difficultyReduction > 0)
                  Positioned(
                    top: 132,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '-${gameRound.difficultyReduction} Level',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_showResultFeedback)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'USED',
                            style: GoogleFonts.montserrat(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap to clear',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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

  Widget _buildCharacterDisplay() {
    final isCompactHeight = MediaQuery.of(context).size.height < 500;
    final titlePaddingV = isCompactHeight ? 4.0 : 8.0;
    final imageHeight = isCompactHeight ? 120.0 : 188.0;
    final imageWidth = isCompactHeight ? 100.0 : 150.0;
    final buttonHeight = isCompactHeight ? 32.0 : 46.0;
    final buttonFontSize = isCompactHeight ? 10.0 : 14.0;
    final buttonPadding = isCompactHeight ? 4.0 : 7.0;

    if (selectedCharacter == null) {
      return SizedBox(
        width: 244,
        child: Container(
          width: 228,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.pureWhite.withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(
              FeatherIcons.alertCircle,
              color: AppColors.textSecondary.withOpacity(0.5),
              size: 36,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 244,
      child: Container(
        width: 228,
        margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: titlePaddingV,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Center(
                    child: Text(
                      selectedCharacter!.title,
                      style: GoogleFonts.montserrat(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isCompactHeight ? 4 : 6,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      _boardCharacterAssetPath(selectedCharacter!.title),
                      height: imageHeight,
                      width: imageWidth,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: imageHeight,
                          width: imageWidth,
                          color: AppColors.softGray.withOpacity(0.12),
                          child: const Icon(
                            FeatherIcons.image,
                            color: Colors.black54,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _buildGameStatsHeader(),
                Padding(
                  padding: EdgeInsets.all(buttonPadding),
                  child: GestureDetector(
                    onTap: () => _showCharacterSheet(selectedCharacter!),
                    child: Container(
                      width: double.infinity,
                      height: buttonHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _buttonGreen,
                        borderRadius: BorderRadius.circular(51),
                        border: Border.all(color: _buttonBorder, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'View Char Sheet',
                        style: GoogleFonts.montserrat(
                          color: Colors.black,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, buttonPadding),
                  child: GestureDetector(
                    onTap: _showSpinWheel,
                    child: Container(
                      width: double.infinity,
                      height: buttonHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _buttonGreen,
                        borderRadius: BorderRadius.circular(51),
                        border: Border.all(color: _buttonBorder, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'Solve Global Issue',
                        style: GoogleFonts.montserrat(
                          color: Colors.black,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, buttonPadding),
                  child: GestureDetector(
                    onTap: _handleMapButtonTap,
                    child: Container(
                      width: double.infinity,
                      height: buttonHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _buttonGreen,
                        borderRadius: BorderRadius.circular(51),
                        border: Border.all(color: _buttonBorder, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'Check the Map',
                        style: GoogleFonts.montserrat(
                          color: Colors.black,
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
