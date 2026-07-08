import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/game_models.dart';
import '../../models/room_model.dart';
import '../../services/auth_service.dart';
import '../../services/game_state_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background_decoration.dart';
import 'character_selection_page.dart';
import 'character_sheet_dialog.dart';
import 'interactive_map_dialog.dart';
import 'spin_wheel_dialog.dart';
import 'win_profile_dialog.dart';

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
  int _policymakerBuff = 0; // +1 dice buff from adjacent Policymaker
  // Region selection tracking for multiplayer initial map selection
  bool _hasPickedInitialRegion = false;
  bool _isInitialMapDialogOpen = false;
  /// Guard flag: prevents showing game-over dialog more than once
  bool _gameOverShown = false;

  /// Real-time regions notifier for map dialog (updates when _mpGameState changes)
  late final ValueNotifier<Map<String, String>> _regionsNotifier;

  /// Region adjacency map for Policymaker buff
  static const Map<String, List<String>> _regionAdjacency = {
    'North America': ['Europe', 'Central & South America'],
    'Central & South America': ['North America', 'Africa'],
    'Europe': ['North America', 'Africa', 'Asia'],
    'Africa': ['Central & South America', 'Europe', 'Asia'],
    'Asia': ['Europe', 'Africa'],
  };

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
    _regionsNotifier = ValueNotifier<Map<String, String>>(
      _isMultiplayer && _mpGameState != null
          ? _mpGameState!.getAllPlayerRegions()
          : {},
    );
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

    // Load MY region from action_log (per-player, not shared state)
    if (_mpGameState != null) {
      final myRegion = _mpGameState!.getPlayerRegion(_myPlayerId);
      if (myRegion != null) {
        gameRound.setRegion(myRegion);
      }
    }

    _gameStateChannel = GameStateService.instance.streamGameState(
      roomId: widget.multiplayerRoomId!,
      onUpdate: _onGameStateUpdated,
    );
    
    // Sync initial hand cards to multiplayer state
    GameStateService.instance.syncPlayerHandCards(
      roomId: widget.multiplayerRoomId!,
      playerId: _myPlayerId,
      handCards: gameRound.handCards,
    ).catchError((_) {
      // Silently fail if sync doesn't work
    });
    
    // Show map for initial region selection in multiplayer
    // Only show if not all players have already selected regions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMultiplayer && _mpGameState != null) {
        final regions = _mpGameState!.getAllPlayerRegions();
        final allPicked = regions.length >= _mpPlayers.length;
        if (!allPicked) {
          _showMapPopup(forceSelect: true);
        } else {
          _hasPickedInitialRegion = true;
        }
      } else {
        _showMapPopup(forceSelect: true);
      }
    });
  }

  void _onGameStateUpdated(MultiplayerGameState state) {
    if (!mounted) return;
    setState(() {
      _mpGameState = state;
      // Sync SHARED game state only (energy, peace, token positions, round info)
      gameRound.energy = state.energy;
      gameRound.peace = state.peace;
      gameRound.crisisTokens = state.crisisTokens;
      _sustainableTokenPosition = state.sustainableTokenPosition;
      _crisisTokenPosition = state.crisisTokenPosition;
      // DO NOT overwrite gameRound.selectedRegion or gameRound.currentEcoCrisisLevel
      // These are PER-PLAYER values stored in action_log, not shared state.
      // Overwriting from shared state causes wrong eco crisis card images.
    });
    _updateTurnState();
    _checkPolicymakerBuff();

    // Update regions notifier for real-time map updates
    if (_isMultiplayer && _mpGameState != null) {
      _regionsNotifier.value = _mpGameState!.getAllPlayerRegions();
    }

    // Check for game-over conditions triggered by another player's real-time update.
    // When the active player triggers WIN/LOSE locally, _gameOverShown prevents duplicate.
    if (_isMultiplayer && !_gameOverShown) {
      if (_sustainableTokenPosition >= 13) {
        // Another player won the game — show win dialog for all players
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_gameOverShown) _showGameOverDialog(playerWon: true);
        });
      } else if (_crisisTokenPosition >= 13) {
        // Another player lost the game — show lose dialog for all players
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_gameOverShown) _showGameOverDialog(playerWon: false);
        });
      }
    }

    // Auto-dismiss initial map dialog when all players have picked regions
    if (_isMultiplayer && _isInitialMapDialogOpen && _mpGameState != null) {
      final regions = _mpGameState!.getAllPlayerRegions();
      final allPicked = regions.length >= _mpPlayers.length;
      if (allPicked) {
        _hasPickedInitialRegion = true;
        // Small delay so the waiting overlay is visible briefly
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isInitialMapDialogOpen) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  /// Check if any teammate with Policymaker character is in an adjacent region
  void _checkPolicymakerBuff() {
    if (!_isMultiplayer || _mpGameState == null) {
      _policymakerBuff = 0;
      return;
    }
    final myRegion = _mpGameState!.getPlayerRegion(_myPlayerId);
    if (myRegion == null) {
      _policymakerBuff = 0;
      return;
    }
    final adjacentRegions = _regionAdjacency[myRegion] ?? [];
    final allRegions = _mpGameState!.getAllPlayerRegions();
    int buff = 0;
    RoomPlayer? policymakerPlayer;
    
    for (final player in _mpPlayers) {
      if (player.playerId == _myPlayerId) continue;
      if (player.characterName?.toLowerCase() == 'policymaker') {
        final theirRegion = allRegions[player.playerId];
        if (theirRegion != null && adjacentRegions.contains(theirRegion)) {
          buff = 1;
          policymakerPlayer = player;
          break;
        }
      }
    }
    
    if (buff != _policymakerBuff) {
      setState(() => _policymakerBuff = buff);
      // Buff applies silently - no notification popup
    }
  }

  /// Sync region selection to Supabase action_log
  Future<void> _syncRegionToActionLog(String region) async {
    if (!_isMultiplayer) return;
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      selectedRegion: region,
      appendActionLog: {
        'type': 'region_select',
        'player_id': _myPlayerId,
        'region': region,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Validate region selection - re-reads latest state to prevent race conditions.
  /// Returns true if the region is still available.
  Future<bool> _validateRegion(String region) async {
    if (!_isMultiplayer) return true;
    try {
      final freshState = await GameStateService.instance.getGameState(
        widget.multiplayerRoomId!,
      );
      if (freshState == null) return true;
      final regions = freshState.getAllPlayerRegions();
      // Check if another player already took this region
      for (final entry in regions.entries) {
        if (entry.key != _myPlayerId && entry.value == region) {
          return false; // Conflict!
        }
      }
      return true;
    } catch (_) {
      return true; // On error, allow selection
    }
  }

  /// Sync hand cards to Supabase action_log
  Future<void> _syncHandCardsToActionLog() async {
    if (!_isMultiplayer) return;
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      appendActionLog: {
        'type': 'hand_cards_sync',
        'player_id': _myPlayerId,
        'cards': gameRound.handCards.toList(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
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
  /// NOTE: Only syncs SHARED state (tokens, energy, peace).
  /// Per-player state (region, ecoCrisisLevel) is stored in action_log separately.
  Future<void> _syncToSupabase() async {
    if (!_isMultiplayer || !_isMyTurn) return;
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      energy: gameRound.energy,
      peace: gameRound.peace,
      crisisTokens: gameRound.crisisTokens,
      sustainableTokenPosition: _sustainableTokenPosition,
      crisisTokenPosition: _crisisTokenPosition,
    );
  }

  Future<void> _endTurn() async {
    if (!_isMultiplayer || !_isMyTurn) return;

    // Sort players by joinedAt to get a CONSISTENT, deterministic turn order
    final sortedPlayers = List<RoomPlayer>.from(_mpPlayers)
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final playerOrder = sortedPlayers.map((p) => p.playerId).toList();

    // Optimistically update UI
    setState(() {
      _isMyTurn = false;
    });

    try {
      await GameStateService.instance.nextTurn(
        roomId: widget.multiplayerRoomId!,
        playerOrder: playerOrder,
        currentPlayerId: _myPlayerId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMyTurn = true; // revert
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengakhiri giliran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _pickRandomActionCards() {
    final cards = List<String>.from(_actionCardAssets);
    
    // In multiplayer, exclude Card #3 (Region Change) since regions are pre-assigned
    if (widget.multiplayerRoomId != null) {
      cards.removeWhere((card) => card == 'assets/action_card/3.png');
    }
    
    cards.shuffle(math.Random());
    return cards.take(3).toList();
  }

  @override
  void dispose() {
    _gameStateChannel?.unsubscribe();
    _fadeController.dispose();
    _regionsNotifier.dispose();
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
    if (_isMultiplayer && !_isMyTurn) return false;
    switch (number) {
      case 1:
        return (gameRound.currentEcoCrisisLevel -
                gameRound.difficultyReduction) >
            1;
      case 2:
        return _crisisTokenPosition > 0;
      case 3:
        return !_isMultiplayer; // Plane card disabled in multiplayer
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
    if (!_isCardUsable(number)) {
      if (_isMultiplayer && !_isMyTurn) {
        _showCardSnack('Belum giliranmu! Tunggu pemain lain selesai.');
      } else {
        _showCardSnack('Kartu ini belum bisa digunakan sekarang.');
      }
      return;
    }

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
            child: SingleChildScrollView(
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
    _syncHandCardsToActionLog();

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
        _syncToSupabase();
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
    
    // Get available cards, filtering Card #3 in multiplayer
    final availableCards = List<String>.from(_actionCardAssets);
    if (widget.multiplayerRoomId != null) {
      availableCards.removeWhere((card) => card == 'assets/action_card/3.png');
    }
    
    final picked = availableCards[math.Random().nextInt(availableCards.length)];
    setState(() => gameRound.handCards.add(picked));
    
    // Sync cards to multiplayer state if in multiplayer
    if (_isMultiplayer && widget.multiplayerRoomId != null) {
      GameStateService.instance.syncPlayerHandCards(
        roomId: widget.multiplayerRoomId!,
        playerId: _myPlayerId,
        handCards: gameRound.handCards,
      ).catchError((_) {
        // Silently fail if sync doesn't work - cards still exist locally
      });
    }

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
          existingPlayerRegions: _isMultiplayer ? _mpGameState?.getAllPlayerRegions() : null,
          players: _isMultiplayer ? _mpPlayers : null,
          myPlayerId: _isMultiplayer ? _myPlayerId : null,
          onValidateRegion: _isMultiplayer ? _validateRegion : null,
          regionsNotifier: _isMultiplayer ? _regionsNotifier : null,
          onRegionSelected: (selectedRegion) {
            setState(() {
              gameRound.setRegion(selectedRegion);
            });
            _syncRegionToActionLog(selectedRegion);
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
            existingPlayerRegions: _isMultiplayer ? _mpGameState?.getAllPlayerRegions() : null,
            players: _isMultiplayer ? _mpPlayers : null,
            myPlayerId: _isMultiplayer ? _myPlayerId : null,
            regionsNotifier: _isMultiplayer ? _regionsNotifier : null,
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
                          'Need Region Change card to change region!',
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
    
    // Determine current eco crisis type (climate, ecology, or energy)
    final ecoCrisisType = _getBadgeTypeForCard(
      gameRound.selectedRegion,
      currentLevel,
      currentVariant,
    );

    // Calculate character passive reduction (don't modify gameRound state!)
    int characterPassiveReduction = 0;
    String? characterName = selectedCharacter?.title.toLowerCase();
    if (characterName == 'climate engineer' && ecoCrisisType == 'climate') {
      characterPassiveReduction = 1;
    } else if (characterName == 'ecologist' && ecoCrisisType == 'ecology') {
      characterPassiveReduction = 1;
    } else if (characterName == 'energy scientist' && ecoCrisisType == 'energy') {
      characterPassiveReduction = 1;
    }

    // Calculate effectiveLevel with both card buff and character passive
    // Apply Policymaker buff (+1 to spin result effectively = -1 to effective level)
    final policyBuff = _policymakerBuff;

    final effectiveLevel = (currentLevel - gameRound.difficultyReduction - characterPassiveReduction - policyBuff).clamp(
      1,
      99,
    );

    // Don't reset card buffs here - they should persist across rerolls!
    // Buffs will be reset when round ends (WIN/LOSE)

    final resultLevel = int.tryParse(result) ?? 0;

    // Card 7 buff: any number wins (don't reset yet!)
    final bool anyWins = gameRound.anyNumberWins;

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
        // Reset card buffs when round ends
        gameRound.difficultyReduction = 0;
        gameRound.anyNumberWins = false;
        gameRound.randomizeEcoCrisisLevel();
      });
      _syncToSupabase();

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
          // Reset card buffs when round ends
          gameRound.difficultyReduction = 0;
          gameRound.anyNumberWins = false;
          // User asked for this logic
          gameRound.randomizeEcoCrisisLevel();
        });

        // Apply character passive: Environmental Activist gets +1 extra step on win
        if (characterName == 'environmental activist') {
          setState(() {
            _sustainableTokenPosition = (_sustainableTokenPosition + 1).clamp(
              0,
              13,
            );
          });
        }

        // Sync AFTER all token movements (including character passives)
        _syncToSupabase();

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
          gameRound.crisisTokens = _crisisTokenPosition; // Sync token
          gameRound.failCount++;
          _showResultFeedback = true;
          // Reset card buffs when round ends
          gameRound.difficultyReduction = 0;
          gameRound.anyNumberWins = false;
          gameRound.randomizeEcoCrisisLevel();
        });
        _syncToSupabase();

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
    
    // Auto-switch turn in multiplayer after action completes
    if (_isMultiplayer && _isMyTurn) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _endTurn();
        }
      });
    }
  }

  /// Helper method to get character name from selectedCharacter
  String? _getCharacterName() {
    return selectedCharacter?.title.toLowerCase();
  }

  /// Build character passive skill badge - only show if passive applies to current eco crisis type
  Widget _buildCharacterPassiveBadge() {
    if (selectedCharacter == null) {
      return const SizedBox.shrink();
    }

    final charName = selectedCharacter!.title.toLowerCase();
    final currentLevel = gameRound.currentEcoCrisisLevel;
    final currentVariant = gameRound.currentEcoCrisisVariant;
    
    // Determine current eco crisis type
    final ecoCrisisType = _getBadgeTypeForCard(
      gameRound.selectedRegion,
      currentLevel,
      currentVariant,
    );

    String badgeText = '';
    Color badgeColor = Colors.grey;
    bool showBadge = false;

    // Only show badge if character passive applies to THIS eco crisis type
    if (charName == 'climate engineer' && ecoCrisisType == 'climate') {
      badgeText = '-1 Level';
      badgeColor = const Color(0xFFF06292);
      showBadge = true;
    } else if (charName == 'ecologist' && ecoCrisisType == 'ecology') {
      badgeText = '-1 Level';
      badgeColor = const Color(0xFFED9B3B);
      showBadge = true;
    } else if (charName == 'energy scientist' && ecoCrisisType == 'energy') {
      badgeText = '-1 Level';
      badgeColor = const Color(0xFF6C63FF);
      showBadge = true;
    } else if (charName == 'environmental activist') {
      badgeText = '+1 Step';
      badgeColor = const Color(0xFF38A3A5);
      showBadge = true;
    } else if (charName == 'policymaker') {
      badgeText = 'Buff\nAdjacent';
      badgeColor = const Color(0xFFB07D54);
      showBadge = _isMultiplayer; // Only show in multiplayer
    }

    // Show received Policymaker buff badge for non-Policymaker characters
    if (_policymakerBuff > 0 && charName != 'policymaker') {
      badgeText = badgeText.isNotEmpty ? '$badgeText\n🏛️+1' : '🏛️+1';
      showBadge = true;
    }

    if (!showBadge) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        badgeText,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          height: 1.2,
        ),
      ),
    );
  }

  void _promptCard6Reroll() {
    final card6Path = _cardPath(6)!;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final imgSize = (maxH * 0.25).clamp(80.0, 140.0);
              return Container(
                constraints: BoxConstraints(
                  maxWidth: 320,
                  maxHeight: maxH * 0.85,
                ),
                padding: const EdgeInsets.all(16),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          card6Path,
                          height: imgSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You got FAIL!\nUse Re-Spin card?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                  fontSize: 12,
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
          gameRound.crisisTokens = _crisisTokenPosition; // Sync token
          gameRound.failCount++;
          _showResultFeedback = true;
          gameRound.randomizeEcoCrisisLevel();
        });
        _syncToSupabase();
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

        // End turn in multiplayer after Card 6 "No, Fail" decision
        if (_isMultiplayer && _isMyTurn) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _endTurn();
          });
        }
      }
    });
  }

  /// Save LOSE result to game_results table (mirrors WinProfileDialog's save logic)
  Future<void> _saveLoseResult() async {
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      final profile = await LeaderboardService.instance.getPlayerProfile(playerId);
      String displayName = profile?.displayName ?? 'Player';
      if (profile == null) {
        final username = await AuthService.instance.getUsername();
        if (username != null) displayName = username;
      }

      final badgeMap = <String, int>{
        'climate': gameRound.getBadgeLevel('climate'),
        'ecology': gameRound.getBadgeLevel('ecology'),
        'energy': gameRound.getBadgeLevel('energy'),
      };

      final score = (gameRound.successCount * 100 +
              badgeMap.values.fold(0, (a, b) => a + b) * 50 -
              gameRound.failCount * 10)
          .clamp(0, 999999);

      await LeaderboardService.instance.submitResult(
        playerId: playerId,
        displayName: displayName,
        country: profile?.country,
        bio: profile?.bio,
        character: widget.selectedCharacterName,
        region: gameRound.selectedRegion,
        difficulty: widget.selectedDifficulty,
        mode: _isMultiplayer ? 'multiplayer' : 'singleplayer',
        result: 'lose',
        winCount: gameRound.successCount,
        loseCount: gameRound.failCount,
        score: score,
        badges: badgeMap,
      );
    } catch (_) {
      // Silently fail — don't block the game over dialog
    }
  }

  void _showGameOverDialog({required bool playerWon}) {
    // Guard: prevent showing game-over dialog more than once
    if (_gameOverShown) return;
    _gameOverShown = true;

    if (playerWon) {
      // WIN — show profile input dialog
      final badgeMap = <String, int>{
        'climate': gameRound.getBadgeLevel('climate'),
        'ecology': gameRound.getBadgeLevel('ecology'),
        'energy': gameRound.getBadgeLevel('energy'),
      };
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WinProfileDialog(
          winCount: gameRound.successCount,
          loseCount: gameRound.failCount,
          character: widget.selectedCharacterName,
          region: gameRound.selectedRegion,
          difficulty: widget.selectedDifficulty,
          mode: _isMultiplayer ? 'multiplayer' : 'singleplayer',
          badges: badgeMap,
          onDone: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      );
      return;
    }

    // LOSE — save result then show dialog
    _saveLoseResult();

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
                color: const Color(0xFFEB5757),
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
                  'YOU LOSE!',
                  style: GoogleFonts.montserrat(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEB5757),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Planetary Crisis reached the goal! 🌍',
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEB5757),
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
    VoidCallback? onClosed,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
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
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: isSuccess
                        ? const Color(0xFFA5C18A)
                        : const Color(0xFFEB5757),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
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

  void _showMapPopup({bool forceSelect = false}) {
    _isInitialMapDialogOpen = forceSelect;
    showDialog<void>(
      context: context,
      barrierDismissible: !forceSelect,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return InteractiveMapDialog(
          characterName: widget.selectedCharacterName,
          characterAccentColor: widget.characterAccentColor,
          initialRegion: gameRound.selectedRegion,
          existingPlayerRegions: _isMultiplayer ? _mpGameState?.getAllPlayerRegions() : null,
          players: _isMultiplayer ? _mpPlayers : null,
          myPlayerId: _isMultiplayer ? _myPlayerId : null,
          forceSelect: forceSelect,
          totalPlayers: _isMultiplayer ? _mpPlayers.length : 0,
          onValidateRegion: _isMultiplayer ? _validateRegion : null,
          regionsNotifier: _isMultiplayer ? _regionsNotifier : null,
          onRegionSelected: (selectedRegion) {
            setState(() {
              gameRound.setRegion(selectedRegion);
              if (forceSelect) _hasPickedInitialRegion = true;
            });
            _syncRegionToActionLog(selectedRegion);
          },
        );
      },
    ).then((_) {
      _isInitialMapDialogOpen = false;
    });
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
                      // 4. Game content overlay with responsive layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 800;
                          final isSmallPhone = constraints.maxWidth < 420;
                          
                          if (isMobile) {
                            // Mobile: compact stacked layout
                            final photoW = isSmallPhone ? 140.0 : 170.0;
                            return SafeArea(
                              child: Column(
                                children: [
                                  // Top: token track (full width)
                                  _buildTokenTrack(),
                                  if (_isMultiplayer) _buildMultiplayerBanner(),
                                  // Middle: photo + character side by side
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: photoW,
                                            child: _buildPhotoDisplayCompact(),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: _buildCharacterDisplayCompact(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Bottom: action cards (full width)
                                  _buildActionCardsStrip(),
                                ],
                              ),
                            );
                          }
                          
                          // Desktop/tablet: original layout with Expanded
                          return SafeArea(
                            child: Row(
                              children: [
                                _buildPhotoDisplay(),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildTokenTrack(),
                                      if (_isMultiplayer) _buildMultiplayerBanner(),
                                      const Expanded(child: SizedBox.expand()),
                                      _buildActionCardsStrip(),
                                    ],
                                  ),
                                ),
                                _buildCharacterDisplay(),
                              ],
                            ),
                          );
                        },
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
  Widget _buildMultiplayerBanner() {
    final currentPlayerName = _mpPlayers
        .where((p) => p.playerId == _mpGameState?.currentPlayerId)
        .map((p) => p.playerName)
        .firstOrNull ?? 'Unknown';
    final allRegions = _mpGameState?.getAllPlayerRegions() ?? {};
    
    // Find current player info
    final currentPlayer = _mpPlayers.firstWhere(
      (p) => p.playerId == _mpGameState?.currentPlayerId,
      orElse: () => _mpPlayers.first,
    );
    final myPlayer = _mpPlayers.firstWhere(
      (p) => p.playerId == _myPlayerId,
      orElse: () => _mpPlayers.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isMyTurn
                ? const Color(0xFF4CAF50).withOpacity(0.5)
                : const Color(0xFFF44336).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current turn player display (prominent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isMyTurn
                    ? const Color(0xFF4CAF50).withOpacity(0.15)
                    : const Color(0xFFF44336).withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  // Current turn player avatar (large)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isMyTurn 
                            ? const Color(0xFF4CAF50) 
                            : const Color(0xFFF44336),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isMyTurn 
                              ? const Color(0xFF4CAF50) 
                              : const Color(0xFFF44336)).withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: currentPlayer.characterAsset != null
                          ? AssetImage(currentPlayer.characterAsset!)
                          : null,
                      child: currentPlayer.characterAsset == null
                          ? const Icon(Icons.person, size: 24)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Current turn info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isMyTurn ? Icons.play_circle_filled : Icons.hourglass_bottom,
                              size: 14,
                              color: _isMyTurn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isMyTurn ? 'YOUR TURN!' : 'WAITING...',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _isMyTurn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isMyTurn ? 'You (${myPlayer.playerName})' : currentPlayerName,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentPlayer.characterName != null)
                          Text(
                            '${currentPlayer.characterName} • ${allRegions[currentPlayer.playerId] ?? '?'}',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Policymaker buff indicator
                  if (_policymakerBuff > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB07D54),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB07D54).withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🏛️',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '+1 BUFF',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Other players (teammates)
            if (_mpPlayers.length > 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAMMATES',
                      style: GoogleFonts.montserrat(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.black45,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _mpPlayers.where((p) => p.playerId != _mpGameState?.currentPlayerId).map((player) {
                        final region = allRegions[player.playerId] ?? '?';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: player.characterAsset != null
                                    ? AssetImage(player.characterAsset!)
                                    : null,
                                child: player.characterAsset == null
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    player.playerName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (player.characterName != null)
                                    Text(
                                      '${player.characterName} • $region',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                // Character Passive Skill Badge
                if (selectedCharacter != null)
                  Positioned(
                    top: 132,
                    right: 4,
                    child: _buildCharacterPassiveBadge(),
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
                    onTap: (_isMultiplayer && !_isMyTurn) ? null : _showSpinWheel,
                    child: AnimatedOpacity(
                      opacity: (_isMultiplayer && !_isMyTurn) ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 200),
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

  /// Compact eco crisis card for mobile layout
  Widget _buildPhotoDisplayCompact() {
    final cardPath = _getEcoCrisisCardPath();

    return GestureDetector(
      onTap: _showPhotoPopup,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.black38, size: 32),
                    ),
                  );
                },
              ),
              if (gameRound.difficultyReduction > 0)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '-${gameRound.difficultyReduction}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (selectedCharacter != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: _buildCharacterPassiveBadge(),
                ),
              if (_showResultFeedback)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Text(
                      'USED',
                      style: GoogleFonts.montserrat(
                        fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white,
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

  /// Compact character panel for mobile layout
  Widget _buildCharacterDisplayCompact() {
    if (selectedCharacter == null) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.pureWhite.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(FeatherIcons.alertCircle, color: Colors.black26, size: 24),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9), topRight: Radius.circular(9),
              ),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Text(
              selectedCharacter!.title,
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w700,
                height: 1, letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Character image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _boardCharacterAssetPath(selectedCharacter!.title),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.softGray.withOpacity(0.12),
                      child: const Icon(FeatherIcons.image, color: Colors.black38, size: 20),
                    );
                  },
                ),
              ),
            ),
          ),
          // Stats + buttons
          _buildGameStatsHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            child: GestureDetector(
              onTap: () => _showCharacterSheet(selectedCharacter!),
              child: Container(
                width: double.infinity,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _buttonGreen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _buttonBorder, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 0, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  'View Sheet',
                  style: GoogleFonts.montserrat(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: GestureDetector(
              onTap: (_isMultiplayer && !_isMyTurn) ? null : _showSpinWheel,
              child: AnimatedOpacity(
                opacity: (_isMultiplayer && !_isMyTurn) ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _buttonGreen,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _buttonBorder, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 0, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    'Solve Issue',
                    style: GoogleFonts.montserrat(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: GestureDetector(
              onTap: _handleMapButtonTap,
              child: Container(
                width: double.infinity,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _buttonGreen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _buttonBorder, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 0, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  'Check Map',
                  style: GoogleFonts.montserrat(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
