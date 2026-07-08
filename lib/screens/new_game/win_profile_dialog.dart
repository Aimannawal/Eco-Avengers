// ============================================================
// GAME RESULT DIALOG
// Auto-save result & show celebratory summary
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart';

class WinProfileDialog extends StatefulWidget {
  final int winCount;
  final int loseCount;
  final String character;
  final String region;
  final String difficulty;
  final String mode;
  final Map<String, int> badges;
  final VoidCallback onDone;

  const WinProfileDialog({
    Key? key,
    required this.winCount,
    required this.loseCount,
    required this.character,
    required this.region,
    required this.difficulty,
    required this.mode,
    required this.badges,
    required this.onDone,
  }) : super(key: key);

  @override
  State<WinProfileDialog> createState() => _WinProfileDialogState();
}

class _WinProfileDialogState extends State<WinProfileDialog>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFFA5C18A);
  static const Color _darkGreen = Color(0xFF4A6741);
  static const Color _border = Color(0xFF111111);
  static const Color _cream = Color(0xFFFAF7F2);
  static const Color _gold = Color(0xFFFFD700);

  bool _isSaving = true;
  bool _saveError = false;
  String? _playerName;
  String? _avatarUrl;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  int get _score =>
      widget.winCount * 100 +
      widget.badges.values.fold(0, (a, b) => a + b) * 50 -
      widget.loseCount * 10;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
    _autoSave();
  }

  Future<void> _autoSave() async {
    if (mounted) setState(() { _isSaving = true; _saveError = false; });
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      final profile = await LeaderboardService.instance.getPlayerProfile(playerId);
      String displayName = profile?.displayName ?? 'Player';
      if (profile == null) {
        final username = await AuthService.instance.getUsername();
        if (username != null) displayName = username;
      }

      if (mounted) {
        setState(() {
          _playerName = displayName;
          _avatarUrl = profile?.avatarUrl;
        });
      }

      await LeaderboardService.instance.submitResult(
        playerId: playerId,
        displayName: displayName,
        country: profile?.country,
        bio: profile?.bio,
        character: widget.character,
        region: widget.region,
        difficulty: widget.difficulty,
        mode: widget.mode,
        result: 'win',
        winCount: widget.winCount,
        loseCount: widget.loseCount,
        score: _score.clamp(0, 999999),
        badges: widget.badges,
      );

      if (mounted) setState(() => _isSaving = false);
    } catch (e) {
      if (mounted) setState(() { _isSaving = false; _saveError = true; });
    }
  }

  Widget _buildBadgeChip(String label, String assetPath, Color color, int level) {
    if (level == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(assetPath, width: 16, height: 16),
          const SizedBox(width: 5),
          Text(
            '$label Lv.$level',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final climateBadge = widget.badges['climate'] ?? 0;
    final ecologyBadge = widget.badges['ecology'] ?? 0;
    final energyBadge = widget.badges['energy'] ?? 0;
    final hasBadges = climateBadge + ecologyBadge + energyBadge > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A6741),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: _gold, size: 52),
                        const SizedBox(height: 8),
                        Text(
                          'YOU WIN! 🎉',
                          style: GoogleFonts.montserrat(
                            color: _gold, fontSize: 28,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The Earth is saved! Great job, Heroes!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Player Info row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        UserAvatar(
                          avatarUrl: _avatarUrl,
                          name: _playerName ?? '?',
                          characterAsset: widget.character.isNotEmpty
                              ? 'assets/vector/${widget.character} Profile.png'
                              : null,
                          radius: 24,
                          borderColor: _darkGreen,
                          borderWidth: 2,
                          backgroundColor: _green.withOpacity(0.3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _playerName ?? '...',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.difficulty} · ${widget.region}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11, color: Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isSaving)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Color(0xFF4A6741),
                            ),
                          )
                        else if (_saveError)
                          const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 22)
                        else
                          const Icon(Icons.cloud_done_rounded, color: Color(0xFF4A6741), size: 22),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _statBox('WIN', '${widget.winCount}', const Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        _statBox('LOSE', '${widget.loseCount}', const Color(0xFFEB5757)),
                        const SizedBox(width: 8),
                        _statBox('SCORE', '${_score.clamp(0, 99999)}', _darkGreen),
                      ],
                    ),
                  ),

                  // Badges
                  if (hasBadges)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BADGES EARNED',
                            style: GoogleFonts.montserrat(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: _darkGreen, letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            children: [
                              _buildBadgeChip('Climate',
                                'assets/vector/Professional Icon Token-Climate Engineering.png',
                                const Color(0xFFF06292), climateBadge),
                              _buildBadgeChip('Ecology',
                                'assets/vector/Professional Icon Token-Environmental Ecology.png',
                                const Color(0xFFED9B3B), ecologyBadge),
                              _buildBadgeChip('Energy',
                                'assets/vector/Professional Icon Token-Energy Science.png',
                                const Color(0xFF6C63FF), energyBadge),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Error state
                  if (_saveError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Result not saved. Check your connection.',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11, color: Colors.red.shade700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _autoSave,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Retry',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Back to Home button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                          side: const BorderSide(color: _border, width: 2.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        icon: const Icon(Icons.home_rounded, size: 20),
                        label: Text(
                          'Back to Home',
                          style: GoogleFonts.montserrat(
                            fontSize: 16, fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.montserrat(
              fontSize: 20, fontWeight: FontWeight.w900, color: color,
            )),
            Text(label, style: GoogleFonts.montserrat(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: Colors.black54, letterSpacing: 0.5,
            )),
          ],
        ),
      ),
    );
  }
}
