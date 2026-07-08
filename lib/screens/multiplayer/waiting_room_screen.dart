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
  static const Color _feltColor = Color(0xFF6A9073);
  static const Color _borderColor = Color(0xFF111111);
  static const Color _buttonColor = Color(0xFFA5C18A);

  late GameRoom _room;
  List<RoomPlayer> _players = [];
  String _myPlayerId = '';
  bool _isStarting = false;

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
        if (!mounted) return;
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _feltColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _borderColor, width: 3),
        ),
        title: Text(
          'Room Ditutup',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Host telah meninggalkan room. Kamu akan kembali ke menu.',
          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(
                color: _buttonColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
          SnackBar(content: Text('Gagal mulai game: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _leaveRoom() async {
    await RoomService.instance.leaveRoom(_room.id);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    _playersChannel?.unsubscribe();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _isHost => _room.hostPlayerId == _myPlayerId;
  bool get _canStart => _players.length >= AppConstants.minPlayers && _isHost;

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
            'assets/background/kayu.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.12)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final isCompact = constraints.maxHeight < 500;
                  final boardWidth = isWide
                      ? math.min(constraints.maxWidth * 0.72, 640.0)
                      : constraints.maxWidth * 0.90;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 24),
                      child: SizedBox(
                        width: boardWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // ── Main Board ──
                            Container(
                              decoration: BoxDecoration(
                                color: _feltColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _borderColor, width: 3.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.fromLTRB(
                                24,
                                isCompact ? 20 : 36,
                                24,
                                isCompact ? 12 : 28,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title
                                  Text(
                                    'WAITING ROOM',
                                    style: GoogleFonts.montserrat(
                                      fontSize: isCompact ? 16 : (isWide ? 26 : 20),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 6 : 8),

                                  // Room Code Card
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                        text: _room.roomCode,
                                      ));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Kode room "${_room.roomCode}" disalin!',
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: Colors.green.shade700,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: isCompact ? 6 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.copy_rounded,
                                            color: Colors.white60,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            children: [
                                              Text(
                                                'KODE ROOM',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: Colors.white60,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                              Text(
                                                _room.roomCode,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: isCompact ? 22 : 32,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 3 : 6),
                                  Text(
                                    'Tap kode untuk menyalin • Bagikan ke teman',
                                    style: GoogleFonts.montserrat(
                                      fontSize: isCompact ? 10 : 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 8 : 16),

                                  // Info badges
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _InfoBadge(
                                        label: 'Mode: $_difficultyLabel',
                                        icon: Icons.tune_rounded,
                                      ),
                                      const SizedBox(width: 8),
                                      _InfoBadge(
                                        label: '${_players.length}/${_room.maxPlayers} Pemain',
                                        icon: Icons.people_outline_rounded,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isCompact ? 10 : 20),

                                  // Player list header
                                  Row(
                                    children: [
                                      Text(
                                        'PEMAIN',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white70,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isCompact ? 4 : 8),

                                  // Player list
                                  ...List.generate(
                                    math.max(_players.length, AppConstants.minPlayers),
                                    (i) {
                                      if (i < _players.length) {
                                        return _PlayerTile(
                                          player: _players[i],
                                          isMe: _players[i].playerId == _myPlayerId,
                                          compact: isCompact,
                                        );
                                      } else {
                                        return _EmptyPlayerSlot(
                                          index: i + 1,
                                          compact: isCompact,
                                        );
                                      }
                                    },
                                  ),

                                  SizedBox(height: isCompact ? 12 : 24),

                                  // Start button (host only)
                                  if (_isHost) ...[
                                    _WaitingButton(
                                      label: _canStart
                                          ? 'MULAI GAME'
                                          : 'Tunggu ${AppConstants.minPlayers - _players.length} pemain lagi...',
                                      icon: _canStart
                                          ? Icons.play_arrow_rounded
                                          : Icons.hourglass_top_rounded,
                                      enabled: _canStart,
                                      isLoading: _isStarting,
                                      onTap: _startGame,
                                      buttonColor: _buttonColor,
                                      compact: isCompact,
                                    ),
                                    SizedBox(height: isCompact ? 4 : 10),
                                  ] else ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: isCompact ? 8 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Menunggu host memulai...',
                                            style: GoogleFonts.montserrat(
                                              fontSize: isCompact ? 12 : 14,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: isCompact ? 4 : 10),
                                  ],

                                  // Leave button
                                  TextButton.icon(
                                    onPressed: _leaveRoom,
                                    icon: const Icon(
                                      Icons.exit_to_app_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _isHost ? 'Tutup Room' : 'Keluar Room',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.red.shade300,
                                        fontWeight: FontWeight.w700,
                                        fontSize: isCompact ? 11 : 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Back chip (top-left)
                            Positioned(
                              left: -14,
                              top: -14,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _leaveRoom,
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    width: isWide ? 56 : 48,
                                    height: isWide ? 56 : 48,
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
                                      size: isWide ? 28 : 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
}

// ── Helper Widgets ─────────────────────────────────────────────

class _PlayerTile extends StatelessWidget {
  final RoomPlayer player;
  final bool isMe;
  final bool compact;

  const _PlayerTile({
    required this.player,
    required this.isMe,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 5 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFA5C18A).withOpacity(0.25)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? const Color(0xFFA5C18A).withOpacity(0.6)
              : Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: compact ? 28 : 36,
            height: compact ? 28 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? const Color(0xFFA5C18A)
                  : Colors.white.withOpacity(0.20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              image: player.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(player.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: player.avatarUrl == null
                ? Text(
                    player.playerName.isNotEmpty
                        ? player.playerName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.montserrat(
                      fontSize: compact ? 12 : 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          SizedBox(width: compact ? 8 : 12),
          // Name + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.playerName,
                        style: GoogleFonts.montserrat(
                          fontSize: compact ? 12 : 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      _SmallBadge('Kamu', Colors.green),
                    ],
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      _SmallBadge('Host', Colors.amber),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Ready indicator
          Icon(
            Icons.circle,
            size: 10,
            color: Colors.green.shade400,
          ),
        ],
      ),
    );
  }
}



class _EmptyPlayerSlot extends StatelessWidget {
  final int index;
  final bool compact;
  const _EmptyPlayerSlot({required this.index, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 5 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 28 : 36,
            height: compact ? 28 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white24,
              size: compact ? 16 : 20,
            ),
          ),
          SizedBox(width: compact ? 8 : 12),
          Text(
            'Menunggu pemain...',
            style: GoogleFonts.montserrat(
              fontSize: compact ? 12 : 14,
              color: Colors.white30,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}



class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;
  final Color buttonColor;
  final bool compact;

  const _WaitingButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
    required this.buttonColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (enabled && !isLoading) ? onTap : null,
          borderRadius: BorderRadius.circular(51),
          child: Container(
            width: double.infinity,
            height: compact ? 40 : 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(51),
              border: Border.all(color: const Color(0xFF111111), width: 3),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: isLoading
                ? SizedBox(
                    width: compact ? 18 : 22,
                    height: compact ? 18 : 22,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black54,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: compact ? 18 : 22, color: Colors.black87),
                      SizedBox(width: compact ? 6 : 8),
                      Text(
                        label,
                        style: GoogleFonts.montserrat(
                          fontSize: enabled
                              ? (compact ? 14 : 17)
                              : (compact ? 11 : 13),
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: enabled ? 0.8 : 0.3,
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



