// ============================================================
// WAITING ROOM SCREEN
// Layar lobby setelah create/join room — real-time player list
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../models/room_model.dart';
import '../../services/room_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/retro_window.dart';
import '../new_game/character_selection_page.dart';
import '../new_game/mode_selection_page.dart';

class WaitingRoomScreen extends StatefulWidget {
  final GameRoom room;
  final String playerName;

  const WaitingRoomScreen({
    super.key,
    required this.room,
    required this.playerName,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  late GameRoom _room;
  List<RoomPlayer> _players = [];
  String _myPlayerId = '';
  bool _isStarting = false;
  bool _isLeaving = false;

  RealtimeChannel? _roomChannel;
  RealtimeChannel? _playersChannel;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _init();
  }

  Future<void> _init() async {
    _myPlayerId = await SupabaseService.instance.getOrCreatePlayerId();
    final players = await RoomService.instance.getPlayers(_room.id);
    if (mounted) setState(() => _players = players);
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    // Stream room status changes
    _roomChannel = RoomService.instance.streamRoom(
      roomId: _room.id,
      onUpdate: (room) {
        if (!mounted) return;
        setState(() => _room = room);
        // Jika status berubah ke character_select → navigasi otomatis
        if (room.status == AppConstants.statusCharacterSelect) {
          _navigateToCharacterSelect();
        }
      },
      onDelete: () {
        if (!mounted || _isLeaving) return;
        _showRoomDeletedDialog();
      },
    );

    // Stream player list changes
    _playersChannel = RoomService.instance.streamPlayers(
      roomId: _room.id,
      onUpdate: (players) {
        if (mounted) setState(() => _players = players);
      },
    );
  }

  void _navigateToCharacterSelect() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CharacterSelectionPage(
          difficulty: _room.difficulty,
          characters: ModeSelectionPage.characterOptions,
          multiplayerRoomId: _room.id,
          multiplayerPlayers: _players,
          myPlayerId: _myPlayerId,
        ),
      ),
    );
  }

  void _showRoomDeletedDialog() {
    showRetroAlertDialog(
      context: context,
      title: 'Room Closed',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      message: 'The host has left the room. You will be returned to the menu.',
      confirmLabel: 'OK',
      onConfirm: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      onCancel: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }

  Future<void> _startGame() async {
    if (_players.length < AppConstants.minPlayers) return;

    setState(() => _isStarting = true);
    try {
      await RoomService.instance.updateRoomStatus(
        _room.id,
        AppConstants.statusCharacterSelect,
      );
      // Stream akan otomatis trigger navigasi
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _handleExit() {
    if (_isLeaving) return;
    showRetroAlertDialog(
      context: context,
      title: _isHost ? 'Close Room' : 'Leave Room',
      message: _isHost
          ? 'Are you sure you want to close this room? All players will be disconnected.'
          : 'Are you sure you want to leave this room?',
      confirmLabel: _isHost ? 'CLOSE' : 'LEAVE',
      cancelLabel: 'CANCEL',
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFE04040),
      onConfirm: _leaveRoom,
    );
  }

  Future<void> _leaveRoom() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);

    // Cancel listeners immediately so we don't get self onDelete popups
    _roomChannel?.unsubscribe();
    _playersChannel?.unsubscribe();

    try {
      await RoomService.instance.leaveRoom(_room.id).timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    _playersChannel?.unsubscribe();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _isHost => _room.hostPlayerId == _myPlayerId;

  String get _difficultyLabel {
    switch (_room.difficulty) {
      case AppConstants.difficultyEasy:
        return 'Easy';
      case AppConstants.difficultyHard:
        return 'Hard';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Element Eco Avenger/Menu page/bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = math.min(constraints.maxWidth * 0.92, 540.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: maxWidth,
                        child: _buildRetroContent(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroContent() {
    final int needed = AppConstants.minPlayers - _players.length;
    final bool canStart = _players.length >= AppConstants.minPlayers && _isHost;
    final int maxSlots = math.max(_players.length, AppConstants.minPlayers);

    return RetroWindow(
      title: 'Waiting Room',
      onBack: _handleExit,
      onClose: _handleExit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

            const SizedBox(height: 12),

            // Room Code Box - inset Win95 style
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _room.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Room code "${_room.roomCode}" copied!',
                        style: GoogleFonts.vt323(fontSize: 18)),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFB0B0B0),
                  border: Border(
                    top: BorderSide(color: Colors.black, width: 2),
                    left: BorderSide(color: Colors.black, width: 2),
                    bottom: BorderSide(color: Colors.white, width: 2),
                    right: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'ROOM CODE',
                      style: GoogleFonts.vt323(
                        fontSize: 14,
                        color: Colors.black54,
                        letterSpacing: 2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.content_copy, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          _room.roomCode,
                          style: GoogleFonts.vt323(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'TAP CODE TO COPY • SHARE WITH FRIENDS',
              style: GoogleFonts.vt323(fontSize: 13, color: Colors.black54, letterSpacing: 1),
            ),
            const SizedBox(height: 12),

            // Mode & Player Count Badges (retro speech bubble style)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RetroBadge('$_difficultyLabel Mode'),
                const SizedBox(width: 8),
                _RetroBadge('${_players.length}/${_room.maxPlayers} Players'),
              ],
            ),
            const SizedBox(height: 12),

            // Minimum players warning
            if (_players.length < AppConstants.minPlayers) ...
              [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB0B0B0),
                    border: Border.all(color: Colors.black54, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.black54, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MINIMUM ${AppConstants.minPlayers} PLAYERS REQUIRED',
                              style: GoogleFonts.vt323(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Still need $needed more player${needed > 1 ? 's' : ''}',
                              style: GoogleFonts.vt323(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

            // Players Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PLAYERS',
                style: GoogleFonts.vt323(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Player Slots
            ...List.generate(maxSlots, (i) {
              if (i < _players.length) {
                return _RetroPlayerTile(
                  player: _players[i],
                  isMe: _players[i].playerId == _myPlayerId,
                );
              } else {
                return _RetroEmptySlot();
              }
            }),

            const SizedBox(height: 12),

            // Bottom action bar
            Row(
              children: [
                // Left: status / waiting box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0B0B0),
                      border: Border.all(color: Colors.black54, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            canStart
                                ? 'READY TO START!'
                                : 'WAITING FOR $needed MORE PLAYER${needed > 1 ? 'S' : ''} ...',
                            style: GoogleFonts.vt323(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right: Close/Start button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (_isStarting || _isLeaving)
                      ? null
                      : (_isHost
                          ? (canStart ? _startGame : _handleExit)
                          : _handleExit),
                  child: MouseRegion(
                    cursor: (_isStarting || _isLeaving)
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_isHost && canStart)
                            ? Colors.greenAccent
                            : const Color(0xFFE04040),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isStarting || _isLeaving)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          else
                            Icon(
                              (_isHost && canStart)
                                  ? Icons.play_arrow_rounded
                                  : Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _isLeaving
                                ? 'LEAVING...'
                                : (_isHost
                                    ? (canStart ? 'START' : 'CLOSE ROOM')
                                    : 'LEAVE'),
                            style: GoogleFonts.vt323(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
  }
}


// ── Retro Helper Widgets ─────────────────────────────────────────────

class _RetroBadge extends StatelessWidget {
  final String label;
  const _RetroBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.vt323(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _RetroPlayerTile extends StatelessWidget {
  final RoomPlayer player;
  final bool isMe;
  const _RetroPlayerTile({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFC0C0C0),
        border: Border(
          top: BorderSide(color: Colors.white, width: 2),
          left: BorderSide(color: Colors.white, width: 2),
          bottom: BorderSide(color: Colors.black, width: 2),
          right: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
              border: Border.all(color: Colors.black54, width: 1.5),
              image: player.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(player.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: player.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.black54, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.playerName,
              style: GoogleFonts.vt323(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.green,
              child: Text('You',
                  style: GoogleFonts.vt323(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          if (player.isHost)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.orange,
              child: Text('Host',
                  style: GoogleFonts.vt323(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _RetroEmptySlot extends StatelessWidget {
  const _RetroEmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFB8B8B8),
        border: Border(
          top: BorderSide(color: Colors.white, width: 2),
          left: BorderSide(color: Colors.white, width: 2),
          bottom: BorderSide(color: Colors.black, width: 2),
          right: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.black38, size: 32),
          const SizedBox(width: 10),
          Text(
            'Waiting for players . . .',
            style: GoogleFonts.vt323(
              fontSize: 20,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
