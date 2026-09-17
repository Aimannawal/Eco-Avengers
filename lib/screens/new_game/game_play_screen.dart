import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../models/game_models.dart';
import '../../models/room_model.dart';
import '../../services/auth_service.dart';
import '../../services/game_state_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/room_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'character_selection_page.dart';
import 'character_sheet_dialog.dart';
import 'interactive_map_dialog.dart';
import 'spin_wheel_dialog.dart';
import 'post_spin_dialog.dart';
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
    // card 2 removed
    'assets/action_card/3.png',
    'assets/action_card/4.png',
    // card 5 removed
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
  int _lastProcessedActionLogLength = 0;
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
    'Asia': ['Europe', 'Africa', 'Oceania'],
    'Oceania': ['Asia'],
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
    GameStateService.instance
        .syncPlayerHandCards(
          roomId: widget.multiplayerRoomId!,
          playerId: _myPlayerId,
          handCards: gameRound.handCards,
        )
        .catchError((_) {
          // Silently fail if sync doesn't work
          return _mpGameState!;
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

    // ── Check for incoming card shares & consumed teammate cards ───
    final newLog = state.actionLog;
    final startIdx = math.min(_lastProcessedActionLogLength, newLog.length);
    if (newLog.length > startIdx) {
      final newEntries = newLog.sublist(startIdx);
      _lastProcessedActionLogLength = newLog.length;
      for (final entry in newEntries) {
        if (entry['type'] == 'card_share' &&
            entry['to_player_id'] == _myPlayerId) {
          final card = entry['card'] as String?;
          if (card != null && !gameRound.handCards.contains(card)) {
            final senderName = entry['from_name'] as String? ?? 'teammate';
            gameRound.handCards.add(card);
            // notify user
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🎁 $senderName sent you a card!',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: const Color(0xFF4A6741),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
          }
        } else if (entry['type'] == 'friend_card_used' &&
            entry['from_player_id'] == _myPlayerId) {
          final card = entry['card'] as String?;
          final byName = entry['by_name'] as String? ?? 'Rekan';
          final targetNum = card != null ? _cardNumber(card) : 0;
          final remaining = entry['remaining_cards'] as List<dynamic>?;

          // Hapus kartu teman yang telah terpakai dari tangan
          if (remaining != null) {
            gameRound.handCards = remaining.map((e) => e.toString()).toList();
          } else {
            final matchIdx = gameRound.handCards.indexWhere((c) =>
                c == card ||
                c.replaceAll('\\', '/') == card?.replaceAll('\\', '/') ||
                (targetNum > 0 && _cardNumber(c) == targetNum));
            if (matchIdx != -1) {
              gameRound.handCards.removeAt(matchIdx);
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🤝 $byName menggunakan kartu milikmu (#$targetNum) untuk menyelamatkan tim!',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFF38A3A5),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        } else if (entry['type'] == 'hand_cards_sync' &&
            entry['player_id'] == _myPlayerId) {
          final cards = (entry['cards'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
          if (cards != null && cards.length < gameRound.handCards.length) {
            gameRound.handCards = cards;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        }
      }
    }

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
      } else if (_crisisTokenPosition >= _sustainableTokenPosition) {
        // Planet Crisis caught up to Planet Sustain — game lost for all players
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

  /// Sync badge unlock to Supabase action_log
  Future<void> _syncBadgeToActionLog(String badgeType, int level) async {
    if (!_isMultiplayer) return;
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      appendActionLog: {
        'type': 'badge_unlock',
        'player_id': _myPlayerId,
        'badge': badgeType,
        'level': level,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Share a card to a teammate in multiplayer.
  Future<void> _shareCard(String assetPath) async {
    if (!_isMultiplayer || _mpPlayers.isEmpty) return;

    // Get teammates (excluding self)
    final teammates = _mpPlayers
        .where((p) => p.playerId != _myPlayerId)
        .toList();
    if (teammates.isEmpty) return;

    // Show teammate picker dialog
    final chosenPlayer = await showDialog<RoomPlayer>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF111111), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kirim Kartu ke Siapa?',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kartu akan dipindahkan ke tangan mereka',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...teammates.map((p) {
                final name = p.playerName;
                final charName = p.characterName ?? '';
                return GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(p),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        if (charName.isNotEmpty)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                              image: DecorationImage(
                                image: AssetImage(
                                  'assets/vector/$charName Profile.png',
                                ),
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -2),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Colors.black12,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.black38,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (charName.isNotEmpty)
                                Text(
                                  charName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: Color(0xFF4A6741),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(
                  'Batal',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosenPlayer == null) return;

    // Get my display name
    final profile = await LeaderboardService.instance.getPlayerProfile(
      _myPlayerId,
    );
    final myName = profile?.displayName ?? 'Teammate';

    // Remove from my hand
    setState(() => gameRound.handCards.remove(assetPath));

    // Send via action_log
    await GameStateService.instance.updateGameState(
      widget.multiplayerRoomId!,
      appendActionLog: {
        'type': 'card_share',
        'from_player_id': _myPlayerId,
        'from_name': myName,
        'to_player_id': chosenPlayer.playerId,
        'card': assetPath,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Kartu dikirim ke ${chosenPlayer.playerName}!',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF4A6741),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _consumeAllTeammateCards(List<Map<String, String>> usedTeammateCards) async {
    if (!_isMultiplayer || widget.multiplayerRoomId == null || usedTeammateCards.isEmpty) return;
    try {
      final profile = await LeaderboardService.instance.getPlayerProfile(_myPlayerId);
      final myName = profile?.displayName ?? 'Teammate';

      // Kelompokkan kartu berdasarkan pemiliknya (friendId)
      final Map<String, List<String>> cardsByFriend = {};
      for (final item in usedTeammateCards) {
        final fId = item['playerId'] ?? '';
        final cPath = item['card'] ?? '';
        if (fId.isNotEmpty && cPath.isNotEmpty) {
          cardsByFriend.putIfAbsent(fId, () => []).add(cPath);
        }
      }

      for (final entry in cardsByFriend.entries) {
        final friendId = entry.key;
        final cardsToConsume = entry.value;

        // Ambil kartu terakhir milik rekan dari state
        final friendCards = List<String>.from(
          _mpGameState?.getPlayerHandCards(friendId) ?? [],
        );

        for (final cardPath in cardsToConsume) {
          final targetNum = _cardNumber(cardPath);
          final idx = friendCards.indexWhere((c) =>
              c == cardPath ||
              c.replaceAll('\\', '/') == cardPath.replaceAll('\\', '/') ||
              (targetNum > 0 && _cardNumber(c) == targetNum));
          if (idx != -1) {
            friendCards.removeAt(idx);
          }
        }

        // Catat penggunaan kartu teman dan sertakan remaining_cards agar pasti sinkron
        for (final cardPath in cardsToConsume) {
          await GameStateService.instance.updateGameState(
            widget.multiplayerRoomId!,
            appendActionLog: {
              'type': 'friend_card_used',
              'by_player_id': _myPlayerId,
              'by_name': myName,
              'from_player_id': friendId,
              'card': cardPath,
              'remaining_cards': friendCards,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }

        // Sinkronkan daftar kartu tersisa rekan ke action_log
        await GameStateService.instance.syncPlayerHandCards(
          roomId: widget.multiplayerRoomId!,
          playerId: friendId,
          handCards: friendCards,
        );
      }
    } catch (e) {
      print('Error consuming teammate cards: $e');
    }
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
              '🎯 Your turn!',
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

    // Sort players by joinedAt and playerId to get a CONSISTENT, deterministic turn order
    final sortedPlayers = List<RoomPlayer>.from(_mpPlayers)
      ..sort((a, b) {
        int cmp = a.joinedAt.compareTo(b.joinedAt);
        if (cmp == 0) return a.playerId.compareTo(b.playerId);
        return cmp;
      });
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
          content: Text('Failed to end turn: $e'),
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
        isMultiplayer: _isMultiplayer,
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
        return 'Ignore fail and re-spin once';
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
        _showCardSnack('Not your turn! Wait for other players to finish.');
      } else {
        _showCardSnack('This card cannot be used right now.');
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF111111), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
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
                              width: 2.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.fredoka(
                              fontSize: 14,
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
                            backgroundColor: const Color(0xFFFFDB72),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(
                              color: Color(0xFF111111),
                              width: 2.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: Text(
                            'Use Card',
                            style: GoogleFonts.fredoka(
                              fontSize: 14,
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
        _finalizeSpinOutcome(
          result: gameRound.currentEcoCrisisLevel.toString(),
          currentLevel: gameRound.currentEcoCrisisLevel,
          currentVariant: gameRound.currentEcoCrisisVariant,
          characterPassiveReduction: 0,
          policyBuff: _policymakerBuff,
          characterName: selectedCharacter?.title.toLowerCase(),
          isAutoWin: true,
        );
        _showCardSnack('Auto-Win triggered! 🌟');
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
      GameStateService.instance
          .syncPlayerHandCards(
            roomId: widget.multiplayerRoomId!,
            playerId: _myPlayerId,
            handCards: gameRound.handCards,
          )
          .catchError((_) {
            // Silently fail if sync doesn't work - cards still exist locally
            return _mpGameState!;
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
          existingPlayerRegions: _isMultiplayer
              ? _mpGameState?.getAllPlayerRegions()
              : null,
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
    // Map button is always for viewing. Region change is strictly via Card 3 usage.
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogContext) {
        return InteractiveMapDialog(
          characterName: widget.selectedCharacterName,
          characterAccentColor: widget.characterAccentColor,
          initialRegion: gameRound.selectedRegion,
          existingPlayerRegions: _isMultiplayer
              ? _mpGameState?.getAllPlayerRegions()
              : null,
          players: _isMultiplayer ? _mpPlayers : null,
          myPlayerId: _isMultiplayer ? _myPlayerId : null,
          regionsNotifier: _isMultiplayer ? _regionsNotifier : null,
          viewOnly: true,
          onRegionSelected: (selectedRegion) {
            final hasCard = _hasCard(3);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('🔒 ', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasCard
                            ? 'Use the Region Change card from your hand to move!'
                            : 'Need Region Change card to change region!',
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

  // ── Spin result with post-spin card intervention ────────────────────────────

  Future<void> _handleSpinResult(String result) async {
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
    } else if (characterName == 'energy scientist' &&
        ecoCrisisType == 'energy') {
      characterPassiveReduction = 1;
    }

    final policyBuff = _policymakerBuff;

    // Hitung level efektif krisis sebelum intervensi kartu tambahan
    final effectiveLevel = (currentLevel -
            gameRound.difficultyReduction -
            characterPassiveReduction -
            policyBuff)
        .clamp(1, 99);

    final spinNum = int.tryParse(result) ?? 0;
    final bool alreadyWins = (result != 'fail') &&
        (gameRound.anyNumberWins || spinNum >= effectiveLevel);

    // KETENTUAN GAMEPLAY:
    // 1. Jika sudah MENANG (alreadyWins == true), baik Solo maupun Multiplayer, langsung proses hasil tanpa pop up.
    if (alreadyWins) {
      _finalizeSpinOutcome(
        result: result,
        currentLevel: currentLevel,
        currentVariant: currentVariant,
        characterPassiveReduction: characterPassiveReduction,
        policyBuff: policyBuff,
        characterName: characterName,
        isAutoWin: false,
      );
      return;
    }

    // 2. Di Mode Solo (Easy, Medium, Hard) saat KALAH / KURANG POINT:
    // Tampilkan pop up penawaran kartu HANYA jika pemain memiliki kartu di tangan yang CUKUP untuk menang:
    // - Jika spin FAIL: harus punya Card 5 (Auto-win) atau Card 6 (Reroll).
    // - Jika spin angka: harus punya Card 5, Card 7 (Any number wins), atau kartu pengurang level (Card 1, Card 8/9/10 sesuai tipe)
    //   yang jumlah pengurangannya cukup sehingga: effectiveLevel - totalPengurangan <= spinNum.
    // Jika tidak punya kartu yang cukup (misal spin 1, krisis 5, kartu cuma 2 pengurang), langsung kalahkan saja tanpa pop up.
    if (!_isMultiplayer) {
      bool canSoloWin = false;
      final hand = gameRound.handCards;

      if (result == 'fail') {
        canSoloWin = hand.any((c) => _cardNumber(c) == 5);
      } else {
        final hasAutoWin = hand.any((c) => _cardNumber(c) == 5);
        final hasAnyNumberWins = hand.any((c) => _cardNumber(c) == 7);

        int maxReduction = 0;
        for (final c in hand) {
          final num = _cardNumber(c);
          if (num == 1) maxReduction += 1;
          if (num == 8 && ecoCrisisType == 'climate') maxReduction += 1;
          if (num == 9 && ecoCrisisType == 'ecology') maxReduction += 1;
          if (num == 10 && ecoCrisisType == 'energy') maxReduction += 1;
        }

        final potentialTarget = (effectiveLevel - maxReduction).clamp(1, 99);
        final canReachTargetWithReduction = spinNum >= potentialTarget;

        canSoloWin = hasAutoWin || hasAnyNumberWins || canReachTargetWithReduction;
      }

      if (!canSoloWin) {
        _finalizeSpinOutcome(
          result: result,
          currentLevel: currentLevel,
          currentVariant: currentVariant,
          characterPassiveReduction: characterPassiveReduction,
          policyBuff: policyBuff,
          characterName: characterName,
          isAutoWin: false,
        );
        return;
      }
    }

    // Kumpulkan kartu rekan satu tim jika multiplayer dan sedang kalah
    List<TeammateCardInfo> teammates = [];
    if (_isMultiplayer && _mpGameState != null) {
      for (final player in _mpPlayers) {
        if (player.playerId != _myPlayerId) {
          final cards = _mpGameState!.getPlayerHandCards(player.playerId);
          teammates.add(TeammateCardInfo(
            playerId: player.playerId,
            playerName: player.playerName,
            characterName: player.characterName ?? '',
            cards: cards,
          ));
        }
      }
    }

    // Tampilkan Dialog Intervensi Kartu Pasca-Spin (Khusus Multiplayer saat Kalah)
    final decision = await showDialog<PostSpinDecision>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PostSpinDialog(
        spinResult: result,
        currentEcoCrisisLevel: currentLevel,
        baseDifficultyReduction: gameRound.difficultyReduction,
        characterPassiveReduction: characterPassiveReduction,
        policymakerBuff: policyBuff,
        ecoCrisisType: ecoCrisisType,
        anyNumberWins: gameRound.anyNumberWins,
        myHandCards: List<String>.from(gameRound.handCards),
        isMultiplayer: _isMultiplayer,
        teammates: teammates,
      ),
    );

    if (!mounted) return;

    bool isAutoWin = false;

    if (decision != null && !decision.isSkipped) {
      // 1. Konsumsi kartu milik sendiri yang dipilih
      for (final cardPath in decision.usedMyCards) {
        gameRound.useCard(cardPath);
      }
      if (decision.usedMyCards.isNotEmpty) {
        _syncHandCardsToActionLog();
      }

      // 3. Konsumsi kartu rekan tim yang dipilih
      if (decision.usedTeammateCards.isNotEmpty) {
        await _consumeAllTeammateCards(decision.usedTeammateCards);
      }

      // 4. Terapkan pengurangan level krisis dan buff
      gameRound.difficultyReduction += decision.totalDifficultyReduction;
      if (decision.anyNumberWins) {
        gameRound.anyNumberWins = true;
      }
      if (decision.isAutoWin) {
        isAutoWin = true;
      }

      if (decision.isReroll) {
        _showCardSnack('Kartu Reroll digunakan! Silakan spin ulang 🔄');
        setState(() {});
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showSpinWheel();
        });
        return;
      }

      if (decision.usedMyCards.isNotEmpty || decision.usedTeammateCards.isNotEmpty) {
        _showCardSnack('Kartu berhasil digunakan! Efek krisis berkurang.');
      }
      setState(() {});
    }

    // Evaluasi hasil akhir (Win / Fail)
    _finalizeSpinOutcome(
      result: result,
      currentLevel: currentLevel,
      currentVariant: currentVariant,
      characterPassiveReduction: characterPassiveReduction,
      policyBuff: policyBuff,
      characterName: characterName,
      isAutoWin: isAutoWin,
    );
  }

  void _finalizeSpinOutcome({
    required String result,
    required int currentLevel,
    required int currentVariant,
    required int characterPassiveReduction,
    required int policyBuff,
    required String? characterName,
    bool isAutoWin = false,
  }) {
    final effectiveLevel = (currentLevel -
            gameRound.difficultyReduction -
            characterPassiveReduction -
            policyBuff)
        .clamp(1, 99);

    final resultLevel = int.tryParse(result) ?? 0;
    final bool anyWins = gameRound.anyNumberWins;

    print('=== FINALIZE SPIN OUTCOME ===');
    print('Current Level: $currentLevel (effective: $effectiveLevel)');
    print('Spin Result: $result (parsed: $resultLevel)');
    print('Is Auto Win: $isAutoWin | Any Wins: $anyWins');

    if (result == 'fail' && !isAutoWin) {
      // Direct FAIL from wheel
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

      // Check if Planet Crisis caught up to Planet Sustain (game over - players lose)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_crisisTokenPosition >= _sustainableTokenPosition) {
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
      // Check if WIN (numeric result >= effectiveLevel, or anyWins, or isAutoWin)
      final bool isWin = isAutoWin || (anyWins ? result != 'fail' : resultLevel >= effectiveLevel);
      print('Comparing: resultLevel $resultLevel >= effectiveLevel $effectiveLevel = $isWin');

      if (isWin) {
        // WIN
        print('Result: WIN');

        // Unlock badge based on the exact card played
        final badgeType = _getBadgeTypeForCard(
          gameRound.selectedRegion,
          currentLevel,
          currentVariant,
        );
        final badgeUnlocked = gameRound.unlockBadge(badgeType);
        if (badgeUnlocked) {
          _syncBadgeToActionLog(badgeType, gameRound.getBadgeLevel(badgeType));
        }

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
        // FAILED (result < level)
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

        // Check if Planet Crisis caught up to Planet Sustain (game over - players lose)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_crisisTokenPosition >= _sustainableTokenPosition) {
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final imgSize = (maxH * 0.25).clamp(80.0, 140.0);
              return Container(
                constraints: BoxConstraints(
                  maxWidth: 320,
                  maxHeight: maxH * 0.85,
                ),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF111111), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
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
                                  width: 2.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'No, Fail',
                                style: GoogleFonts.fredoka(
                                  fontSize: 13,
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
                                backgroundColor: const Color(0xFFFFDB72),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF111111),
                                  width: 2.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                              child: Text(
                                'Reroll! 🎲',
                                style: GoogleFonts.fredoka(
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
          if (_crisisTokenPosition >= _sustainableTokenPosition)
            _showGameOverDialog(playerWon: false);
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

  /// Score calculation according to Eco Avenger boardgame rules:
  /// +10 pts for each Professional Icon Token
  /// +30 pts for each Professional Master Token
  /// +10 pts per Action Card left in the hands of all team members
  /// +10 pts per Blank space between Planetary Crisis token and Sustainable Planet token
  /// -10 pts per Eco Crisis Card failed to be solved
  Map<String, int> _calculateScoreBreakdown() {
    int totalIconTokens = 0;
    int totalMasterTokens = 0;
    int totalRemainingCards = 0;
    int blanksCount = math.max(0, _sustainableTokenPosition - _crisisTokenPosition - 1);
    int failedCardsCount = gameRound.failCount;

    if (_isMultiplayer && _mpGameState != null) {
      final allBadges = _mpGameState!.getAllPlayerBadges();
      for (final bMap in allBadges.values) {
        for (final lvl in bMap.values) {
          if (lvl >= 1) totalIconTokens += 1;
          if (lvl >= 2) totalIconTokens += 1;
          if (lvl >= 3) totalMasterTokens += 1;
        }
      }
      for (final p in _mpPlayers) {
        final cards = _mpGameState!.getPlayerHandCards(p.playerId);
        if (cards != null && cards.isNotEmpty) {
          totalRemainingCards += cards.length;
        } else if (p.playerId == _myPlayerId) {
          totalRemainingCards += gameRound.handCards.length;
        }
      }
      if (totalRemainingCards == 0) {
        totalRemainingCards = gameRound.handCards.length;
      }
    } else {
      for (final type in ['climate', 'ecology', 'energy']) {
        final lvl = gameRound.getBadgeLevel(type);
        if (lvl >= 1) totalIconTokens += 1;
        if (lvl >= 2) totalIconTokens += 1;
        if (lvl >= 3) totalMasterTokens += 1;
      }
      totalRemainingCards = gameRound.handCards.length;
    }

    final totalScore = math.max(
      0,
      (totalIconTokens * 10) +
      (totalMasterTokens * 30) +
      (totalRemainingCards * 10) +
      (blanksCount * 10) -
      (failedCardsCount * 10),
    );

    return {
      'iconTokens': totalIconTokens,
      'masterTokens': totalMasterTokens,
      'remainingCards': totalRemainingCards,
      'blanks': blanksCount,
      'failedCards': failedCardsCount,
      'totalScore': totalScore,
    };
  }

  /// Save LOSE result to game_results table (mirrors WinProfileDialog's save logic)
  Future<void> _saveLoseResult() async {
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      final profile = await LeaderboardService.instance.getPlayerProfile(
        playerId,
      );
      String displayName = profile?.displayName ?? 'Player';
      if (profile == null) {
        final username = await AuthService.instance.getUsername();
        if (username != null) displayName = username;
      }

      int finalWinCount = gameRound.successCount;
      int finalLoseCount = gameRound.failCount;
      Map<String, int> finalBadgeMap = {
        'climate': gameRound.getBadgeLevel('climate'),
        'ecology': gameRound.getBadgeLevel('ecology'),
        'energy': gameRound.getBadgeLevel('energy'),
      };

      if (_isMultiplayer && _mpGameState != null) {
        finalWinCount = (_sustainableTokenPosition - 4).clamp(0, 999);
        finalLoseCount = _crisisTokenPosition;
        final teamBadges = _mpGameState!.getAllPlayerBadges();

        finalBadgeMap = {'climate': 0, 'ecology': 0, 'energy': 0};
        for (final badges in teamBadges.values) {
          badges.forEach((key, val) {
            if (finalBadgeMap.containsKey(key)) {
              finalBadgeMap[key] = (finalBadgeMap[key] ?? 0) + val;
            }
          });
        }
      }

      final scoreData = _calculateScoreBreakdown();
      final score = scoreData['totalScore'] ?? 0;

      await LeaderboardService.instance.submitResult(
        playerId: playerId,
        displayName: displayName,
        country: profile?.country,
        bio: profile?.bio,
        character: widget.selectedCharacterName,
        region: gameRound.selectedRegion,
        difficulty: widget.selectedDifficulty,
        mode: _isMultiplayer
            ? 'multiplayer_${widget.multiplayerRoomId}'
            : 'singleplayer',
        result: 'lose',
        winCount: finalWinCount,
        loseCount: finalLoseCount,
        score: score,
        badges: finalBadgeMap,
      );
    } catch (_) {
      // Silently fail — don't block the game over dialog
    }
  }

  void _showGameOverDialog({required bool playerWon}) {
    // Guard: prevent showing game-over dialog more than once
    if (_gameOverShown) return;
    _gameOverShown = true;

    // Set room status to finished so it doesn't stay as 'playing' and clutter the database
    if (_isMultiplayer && widget.multiplayerRoomId != null) {
      final isHost = _mpPlayers.any(
        (p) => p.playerId == _myPlayerId && p.isHost,
      );
      if (isHost) {
        RoomService.instance
            .updateRoomStatus(
              widget.multiplayerRoomId!,
              AppConstants.statusFinished,
            )
            .catchError((_) {});
      }
    }

    if (playerWon) {
      // WIN — show profile input dialog
      int finalWinCount = gameRound.successCount;
      int finalLoseCount = gameRound.failCount;
      Map<String, int> finalBadgeMap = {
        'climate': gameRound.getBadgeLevel('climate'),
        'ecology': gameRound.getBadgeLevel('ecology'),
        'energy': gameRound.getBadgeLevel('energy'),
      };

      if (_isMultiplayer && _mpGameState != null) {
        finalWinCount = (_sustainableTokenPosition - 4).clamp(0, 999);
        finalLoseCount = _crisisTokenPosition;
        final teamBadges = _mpGameState!.getAllPlayerBadges();

        finalBadgeMap = {'climate': 0, 'ecology': 0, 'energy': 0};
        for (final badges in teamBadges.values) {
          badges.forEach((key, val) {
            if (finalBadgeMap.containsKey(key)) {
              finalBadgeMap[key] = (finalBadgeMap[key] ?? 0) + val;
            }
          });
        }
      }

      final scoreData = _calculateScoreBreakdown();
      final score = scoreData['totalScore'] ?? 0;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WinProfileDialog(
          winCount: finalWinCount,
          loseCount: finalLoseCount,
          character: widget.selectedCharacterName,
          region: gameRound.selectedRegion,
          difficulty: widget.selectedDifficulty,
          mode: _isMultiplayer
              ? 'multiplayer_${widget.multiplayerRoomId}'
              : 'singleplayer',
          badges: finalBadgeMap,
          score: score,
          iconTokensCount: scoreData['iconTokens'],
          masterTokensCount: scoreData['masterTokens'],
          remainingCardsCount: scoreData['remainingCards'],
          blanksCount: scoreData['blanks'],
          failedCardsCount: scoreData['failedCards'],
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
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF111111), width: 3),
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
                  'GAME OVER',
                  style: GoogleFonts.fredoka(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB5757),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                  ),
                  child: Text(
                    'YOU LOSE!',
                    style: GoogleFonts.fredoka(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                      backgroundColor: const Color(0xFFFFDB72),
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
                      'Back to Menu',
                      style: GoogleFonts.fredoka(
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF111111),
                width: 3,
              ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSuccess ? const Color(0xFF76B828) : const Color(0xFFEB5757),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.fredoka(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClosed?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDB72),
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
                      style: GoogleFonts.fredoka(
                        fontSize: 15,
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
          existingPlayerRegions: _isMultiplayer
              ? _mpGameState?.getAllPlayerRegions()
              : null,
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
        body: RefreshIndicator(
          color: const Color(0xFFA5C18A),
          backgroundColor: Colors.white,
          onRefresh: () async {
            if (_isMultiplayer && widget.multiplayerRoomId != null) {
              final newState = await GameStateService.instance.getGameState(
                widget.multiplayerRoomId!,
              );
              if (newState != null && mounted) {
                _onGameStateUpdated(newState);
              }
              final players = await RoomService.instance.getPlayers(
                widget.multiplayerRoomId!,
              );
              if (mounted) {
                setState(() => _mpPlayers = players);
              }
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompactHeight = constraints.maxHeight < 520;

              return SizedBox(
                height: constraints.maxHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. World map sea background
                    Image.asset(
                      'assets/Element Eco Avenger/boardgame_asset/bg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    // 2. Game content overlay
                    SafeArea(
                      child: Column(
                        children: [
                          // Top: Logo Eco Avengers & Wooden Token Track
                          Padding(
                            padding: EdgeInsets.only(
                              top: isCompactHeight ? 2 : 6,
                              bottom: isCompactHeight ? 2 : 6,
                            ),
                            child: Image.asset(
                              'assets/Element Eco Avenger/boardgame_asset/Logo eco avenger.png',
                              height: isCompactHeight ? 28 : 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                          _buildTokenTrackWooden(isCompactHeight: isCompactHeight),
                          if (_isMultiplayer)
                            _buildMultiplayerBanner(isCompact: isCompactHeight),
                          SizedBox(height: isCompactHeight ? 2 : 8),
                          // Middle: Left (Eco Crisis Card in left.png) + Center (Action cards) + Right (Character in right.png)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              child: LayoutBuilder(
                                builder: (context, middleConstraints) {
                                  final availableH = middleConstraints.maxHeight;
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Left wooden board with Eco Crisis Card
                                      _buildPhotoDisplay(availableH: availableH),
                                      // Center map view area with action cards strip at bottom
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Spacer(),
                                            _buildActionCardsStrip(availableH: availableH),
                                          ],
                                        ),
                                      ),
                                      // Right wooden board with Character & Buttons
                                      _buildCharacterDisplay(availableH: availableH),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplayerBanner({bool isCompact = false}) {
    final currentPlayerName =
        _mpPlayers
            .where((p) => p.playerId == _mpGameState?.currentPlayerId)
            .map((p) => p.playerName)
            .firstOrNull ??
        'Unknown';
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

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: _isMyTurn
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF44336).withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Current Turn status + avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isMyTurn ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: currentPlayer.characterAsset != null
                      ? AssetImage(currentPlayer.characterAsset!)
                      : null,
                  child: currentPlayer.characterAsset == null
                      ? const Icon(Icons.person, size: 13)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isMyTurn ? Icons.play_circle_filled : Icons.hourglass_bottom,
                        size: 10,
                        color: _isMyTurn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isMyTurn ? 'YOUR TURN' : 'WAITING',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: _isMyTurn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _isMyTurn ? 'You (${myPlayer.playerName})' : currentPlayerName,
                    style: GoogleFonts.montserrat(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (_policymakerBuff > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB07D54),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+1 BUFF',
                    style: GoogleFonts.montserrat(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (_mpPlayers.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: VerticalDivider(color: Colors.black.withOpacity(0.15), width: 1),
                ),
                Text(
                  'TEAM:',
                  style: GoogleFonts.montserrat(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _mpPlayers
                          .where((p) => p.playerId != _mpGameState?.currentPlayerId)
                          .map((player) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: player.characterAsset != null
                                          ? AssetImage(player.characterAsset!)
                                          : null,
                                      child: player.characterAsset == null
                                          ? const Icon(Icons.person, size: 9)
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      player.playerName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
                          color:
                              (_isMyTurn
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFF44336))
                                  .withOpacity(0.3),
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
                              _isMyTurn
                                  ? Icons.play_circle_filled
                                  : Icons.hourglass_bottom,
                              size: 14,
                              color: _isMyTurn
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isMyTurn ? 'YOUR TURN!' : 'WAITING...',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _isMyTurn
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isMyTurn
                              ? 'You (${myPlayer.playerName})'
                              : currentPlayerName,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                          const Text('🏛️', style: TextStyle(fontSize: 12)),
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
                      children: _mpPlayers
                          .where(
                            (p) => p.playerId != _mpGameState?.currentPlayerId,
                          )
                          .map((player) {
                            final region = allRegions[player.playerId] ?? '?';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
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
                                    backgroundImage:
                                        player.characterAsset != null
                                        ? AssetImage(player.characterAsset!)
                                        : null,
                                    child: player.characterAsset == null
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                          })
                          .toList(),
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
            '$label: ',
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCardsStrip({double? availableH}) {
    final isCompactHeight = MediaQuery.of(context).size.height < 520;
    final cardHeight = availableH != null
        ? (availableH * 0.40).clamp(48.0, 160.0)
        : (isCompactHeight ? 80.0 : 160.0);
    final cardWidth = cardHeight * (76.0 / 108.0);

    final hand = gameRound.handCards;

    if (hand.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'No action cards in hand',
            style: GoogleFonts.fredoka(
              fontSize: isCompactHeight ? 10 : 12,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final cardWidgets = hand.map((assetPath) {
      final num = _cardNumber(assetPath);
      final usable = _isCardUsable(num);
      final canShare = _isMultiplayer && !_isMyTurn;

      return GestureDetector(
        onTap: () => canShare ? _shareCard(assetPath) : _useCard(assetPath),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isCompactHeight ? 2.5 : 5.0),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Wooden Card Stand: card.png
              Image.asset(
                'assets/Element Eco Avenger/boardgame_asset/card.png',
                width: cardWidth * 1.15,
                height: cardHeight * 1.18,
                fit: BoxFit.fill,
              ),
              // The Action Card itself
              Padding(
                padding: EdgeInsets.fromLTRB(2, cardHeight * 0.08, 2, 4),
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: canShare
                        ? Border.all(color: const Color(0xFF4A90D9), width: 2)
                        : usable
                        ? Border.all(color: const Color(0xFF4CAF50), width: 2)
                        : null,
                    boxShadow: [
                      if (canShare || usable)
                        BoxShadow(
                          color: (canShare
                                  ? const Color(0xFF4A90D9)
                                  : const Color(0xFF4CAF50))
                              .withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Opacity(
                    opacity: (canShare || usable) ? 1.0 : 0.6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // USE / SHARE badge
              if (canShare)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SHARE',
                      style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else if (usable)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'USE',
                      style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: cardWidgets,
        ),
      ),
    );
  }

  Widget _buildTokenTrackWooden({bool isCompactHeight = false}) {
    final boxSize = isCompactHeight ? 24.0 : 44.0;

    // 14 steps palette matching the prototype:
    // Left: reddish pinks (Crisis) -> Center: white (neutral start) -> Right: greens (Sustainable)
    final stepColors = [
      const Color(0xFFD96B6B), // 0: Dark reddish pink
      const Color(0xFFE88E8E), // 1: Medium pink
      const Color(0xFFF0A8A8), // 2: Light pink
      const Color(0xFFF8C6C6), // 3: Very light pink
      const Color(0xFFFFFFFF), // 4: White (neutral start)
      const Color(0xFFFFFFFF), // 5: White
      const Color(0xFFE2ECE0), // 6: Very pale green
      const Color(0xFFC6DEC2), // 7: Pale green
      const Color(0xFFA6CEA0), // 8: Light green
      const Color(0xFF85BE7E), // 9: Green
      const Color(0xFF6FAC67), // 10: Medium green
      const Color(0xFF5F9E58), // 11: Rich green
      const Color(0xFF52904B), // 12: Deep green
      const Color(0xFF45823E), // 13: Dark green
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(14, (index) {
          final isCrisisPosition = index == _crisisTokenPosition;
          final isSustainablePosition = index == _sustainableTokenPosition;

          Widget? tokenWidget;
          if (isCrisisPosition && isSustainablePosition) {
            tokenWidget = Row(
              children: [
                Expanded(
                  child: Image.asset(
                    _planetaryCrisisTokenAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
                Expanded(
                  child: Image.asset(
                    _peaceTokenAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          } else if (isCrisisPosition) {
            tokenWidget = Image.asset(
              _planetaryCrisisTokenAssetPath,
              fit: BoxFit.contain,
            );
          } else if (isSustainablePosition) {
            tokenWidget = Image.asset(
              _peaceTokenAssetPath,
              fit: BoxFit.contain,
            );
          }

          final color = stepColors[index.clamp(0, stepColors.length - 1)];

          return Container(
            width: boxSize,
            height: boxSize,
            margin: EdgeInsets.symmetric(horizontal: isCompactHeight ? 2.0 : 4.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: const Color(0xFF8A5229), // Wooden frame border
                width: isCompactHeight ? 2.0 : 3.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(1, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: tokenWidget == null
                ? null
                : Padding(
                    padding: EdgeInsets.all(isCompactHeight ? 1.5 : 2.5),
                    child: tokenWidget,
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildPhotoDisplay({double? availableH}) {
    final cardPath = _getEcoCrisisCardPath();
    final isCompactHeight = MediaQuery.of(context).size.height < 520;
    final double height = availableH != null
        ? (availableH - 4).clamp(120.0, 420.0)
        : (isCompactHeight ? 230.0 : 420.0);
    final double width = height * (185.0 / 300.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          onTap: _showPhotoPopup,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/Element Eco Avenger/boardgame_asset/left.png'),
                fit: BoxFit.fill,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              width * 0.08,
              height * 0.10,
              width * 0.08,
              height * 0.04,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    cardPath,
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.softGray.withOpacity(0.15),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.black38,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Region: ${gameRound.selectedRegion}\nLevel: ${gameRound.currentEcoCrisisLevel}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
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
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '-${gameRound.difficultyReduction} Level',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (selectedCharacter != null)
                    Positioned(
                      top: 4,
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
                                fontSize: height < 200 ? 20 : 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to clear',
                              style: TextStyle(
                                fontSize: 9,
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
      ),
    );
  }

  Widget _buildCharacterDisplay({double? availableH}) {
    final isCompactHeight = MediaQuery.of(context).size.height < 520;
    final double height = availableH != null
        ? (availableH - 4).clamp(120.0, 420.0)
        : (isCompactHeight ? 230.0 : 420.0);
    final double width = height * (160.0 / 300.0);
    final isVeryCompact = height < 230;

    if (selectedCharacter == null) {
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Element Eco Avenger/boardgame_asset/right.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: const Center(
            child: Icon(
              FeatherIcons.alertCircle,
              color: Colors.black26,
              size: 28,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: SizedBox(
        width: width,
        height: height,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Element Eco Avenger/boardgame_asset/right.png'),
              fit: BoxFit.fill,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            width * 0.07,
            height * 0.03,
            width * 0.07,
            height * 0.03,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Top pill badge with role name:
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isVeryCompact ? 1.0 : 2.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCDCDC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  selectedCharacter!.title.toLowerCase(),
                  style: GoogleFonts.fredoka(
                    fontSize: isVeryCompact ? 9.0 : (isCompactHeight ? 10.5 : 14.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 2. Character Avatar:
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Image.asset(
                    _boardCharacterAssetPath(selectedCharacter!.title),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, size: 36, color: Colors.black38),
                  ),
                ),
              ),

              // 3. Win / Loose pills row:
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isVeryCompact ? 1.0 : 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCDCDC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        'win ${gameRound.successCount}',
                        style: GoogleFonts.fredoka(
                          fontSize: isVeryCompact ? 8.5 : (isCompactHeight ? 9.5 : 12.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isVeryCompact ? 1.0 : 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCDCDC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        'loose ${gameRound.failCount}',
                        style: GoogleFonts.fredoka(
                          fontSize: isVeryCompact ? 8.5 : (isCompactHeight ? 9.5 : 12.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isVeryCompact ? 1 : 2),

              // 4. Action Buttons (pill style with dark borders)
              _buildPrototypePillButton(
                label: 'view character sheet',
                isCompact: isCompactHeight,
                isVeryCompact: isVeryCompact,
                onTap: () => _showCharacterSheet(selectedCharacter!),
              ),
              _buildPrototypePillButton(
                label: 'solve global issues',
                isCompact: isCompactHeight,
                isVeryCompact: isVeryCompact,
                enabled: !(_isMultiplayer && !_isMyTurn),
                onTap: (_isMultiplayer && !_isMyTurn) ? null : _showSpinWheel,
              ),
              _buildPrototypePillButton(
                label: 'check the global issues',
                isCompact: isCompactHeight,
                isVeryCompact: isVeryCompact,
                onTap: _handleMapButtonTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrototypePillButton({
    required String label,
    required VoidCallback? onTap,
    bool enabled = true,
    required bool isCompact,
    bool isVeryCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isVeryCompact ? 1.5 : 2.5),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: isVeryCompact ? 19.0 : (isCompact ? 23.0 : 31.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDCDCDC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: isVeryCompact ? 7.8 : (isCompact ? 8.8 : 11.5),
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.black38,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              if (gameRound.difficultyReduction > 0)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '-${gameRound.difficultyReduction}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
          child: Icon(
            FeatherIcons.alertCircle,
            color: Colors.black26,
            size: 24,
          ),
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
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Text(
              selectedCharacter!.title,
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.2,
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
                      child: const Icon(
                        FeatherIcons.image,
                        color: Colors.black38,
                        size: 20,
                      ),
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
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'View Sheet',
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
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
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Solve Issue',
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
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
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Check Map',
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
