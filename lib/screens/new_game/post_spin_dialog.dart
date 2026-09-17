import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Data kartu rekan satu tim untuk multiplayer
class TeammateCardInfo {
  final String playerId;
  final String playerName;
  final String characterName;
  final List<String> cards;

  const TeammateCardInfo({
    required this.playerId,
    required this.playerName,
    required this.characterName,
    required this.cards,
  });
}

/// Hasil keputusan pemain di dialog post-spin
class PostSpinDecision {
  final List<String> usedMyCards;
  final List<Map<String, String>> usedTeammateCards; // [{ 'playerId': ..., 'card': ... }]
  final bool isReroll;
  final bool isAutoWin;
  final int totalDifficultyReduction;
  final bool anyNumberWins;
  final bool isSkipped;

  const PostSpinDecision({
    this.usedMyCards = const [],
    this.usedTeammateCards = const [],
    this.isReroll = false,
    this.isAutoWin = false,
    this.totalDifficultyReduction = 0,
    this.anyNumberWins = false,
    this.isSkipped = false,
  });
}

class PostSpinDialog extends StatefulWidget {
  final String spinResult; // '1', '2', '3', '4', 'fail'
  final int currentEcoCrisisLevel;
  final int baseDifficultyReduction;
  final int characterPassiveReduction;
  final int policymakerBuff;
  final String ecoCrisisType; // 'climate', 'ecology', 'energy'
  final bool anyNumberWins;
  final List<String> myHandCards;
  final bool isMultiplayer;
  final List<TeammateCardInfo> teammates;

  const PostSpinDialog({
    super.key,
    required this.spinResult,
    required this.currentEcoCrisisLevel,
    required this.baseDifficultyReduction,
    required this.characterPassiveReduction,
    required this.policymakerBuff,
    required this.ecoCrisisType,
    required this.anyNumberWins,
    required this.myHandCards,
    required this.isMultiplayer,
    required this.teammates,
  });

  @override
  State<PostSpinDialog> createState() => _PostSpinDialogState();
}

class _PostSpinDialogState extends State<PostSpinDialog> {
  // Selected cards from own hand: store original indices in widget.myHandCards
  final Set<int> _selectedMyCardIndices = {};

  // Selected cards from teammates: key = "$playerId|$cardPath|$index"
  final Map<String, Map<String, String>> _selectedTeammateCards = {};

  static const Color _primaryGreen = Color(0xFF4A6741);
  static const Color _lightGreen = Color(0xFFA5C18A);
  static const Color _cardBorder = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _autoSelectWinningCards();
  }

  void _autoSelectWinningCards() {
    if (!widget.isMultiplayer) {
      if (widget.spinResult == 'fail') {
        // Prioritas reroll (card 6) atau auto-win (card 5)
        final c6Idx = widget.myHandCards.indexWhere((c) => _cardNumber(c) == 6);
        if (c6Idx != -1) {
          _selectedMyCardIndices.add(c6Idx);
          return;
        }
        final c5Idx = widget.myHandCards.indexWhere((c) => _cardNumber(c) == 5);
        if (c5Idx != -1) {
          _selectedMyCardIndices.add(c5Idx);
          return;
        }
      } else {
        final spinNum = int.tryParse(widget.spinResult) ?? 0;
        final baseEff = (widget.currentEcoCrisisLevel -
                widget.baseDifficultyReduction -
                widget.characterPassiveReduction -
                widget.policymakerBuff)
            .clamp(1, 99);
        final gap = (baseEff - spinNum).clamp(0, 99);

        // Kumpulkan indeks kartu pengurang krisis (Card 1, atau 8/9/10 sesuai tipe krisis)
        final List<int> reductionIndices = [];
        for (int i = 0; i < widget.myHandCards.length; i++) {
          final num = _cardNumber(widget.myHandCards[i]);
          if (num == 1) {
            reductionIndices.add(i);
          } else if (num == 8 && widget.ecoCrisisType == 'climate') {
            reductionIndices.add(i);
          } else if (num == 9 && widget.ecoCrisisType == 'ecology') {
            reductionIndices.add(i);
          } else if (num == 10 && widget.ecoCrisisType == 'energy') {
            reductionIndices.add(i);
          }
        }

        // Jika kartu pengurang cukup untuk menutup gap:
        if (reductionIndices.length >= gap && gap > 0) {
          for (int i = 0; i < gap && i < reductionIndices.length; i++) {
            _selectedMyCardIndices.add(reductionIndices[i]);
          }
          return;
        }

        // Jika tidak cukup dengan pengurang krisis tapi punya Card 7 (Any number wins):
        final c7Idx = widget.myHandCards.indexWhere((c) => _cardNumber(c) == 7);
        if (c7Idx != -1) {
          _selectedMyCardIndices.add(c7Idx);
          return;
        }

        // Atau punya Card 5 (Auto-win):
        final c5Idx = widget.myHandCards.indexWhere((c) => _cardNumber(c) == 5);
        if (c5Idx != -1) {
          _selectedMyCardIndices.add(c5Idx);
          return;
        }
      }
    }
  }

  int _cardNumber(String path) {
    final filename = path.split('/').last.replaceAll('.png', '');
    return int.tryParse(filename) ?? 0;
  }

  String _cardTitle(int number) {
    switch (number) {
      case 1:
        return 'Card #1 (Reduce Level -1)';
      case 5:
        return 'Card #5 (Auto-Win)';
      case 6:
        return 'Card #6 (Reroll)';
      case 7:
        return 'Card #7 (Any Number Wins)';
      case 8:
        return 'Card #8 (Climate Level -1)';
      case 9:
        return 'Card #9 (Ecology Level -1)';
      case 10:
        return 'Card #10 (Energy Level -1)';
      default:
        return 'Card #$number';
    }
  }

  String _cardEffectDesc(int number) {
    switch (number) {
      case 1:
        return 'Mengurangi level krisis sebesar 1 poin';
      case 5:
        return 'Langsung memenangkan krisis saat ini!';
      case 6:
        return 'Abaikan hasil gagal dan putar ulang roda spin 1x';
      case 7:
        return 'Semua angka spin otomatis MENANG';
      case 8:
        return widget.ecoCrisisType == 'climate'
            ? 'Mengurangi level Climate krisis sebesar 1'
            : 'Hanya efektif untuk krisis Climate';
      case 9:
        return widget.ecoCrisisType == 'ecology'
            ? 'Mengurangi level Ecology krisis sebesar 1'
            : 'Hanya efektif untuk krisis Ecology';
      case 10:
        return widget.ecoCrisisType == 'energy'
            ? 'Mengurangi level Energy krisis sebesar 1'
            : 'Hanya efektif untuk krisis Energy';
      default:
        return 'Kartu aksi pendukung';
    }
  }

  bool _isCardHelpful(int number) {
    switch (number) {
      case 1:
        return true;
      case 5:
        return true;
      case 6:
        return widget.spinResult == 'fail';
      case 7:
        return widget.spinResult != 'fail';
      case 8:
        return widget.ecoCrisisType == 'climate';
      case 9:
        return widget.ecoCrisisType == 'ecology';
      case 10:
        return widget.ecoCrisisType == 'energy';
      default:
        return false;
    }
  }

  // Hitung total pengurangan dari kartu yang dipilih
  int _calculateCardReduction() {
    int reduction = 0;

    for (final idx in _selectedMyCardIndices) {
      if (idx >= 0 && idx < widget.myHandCards.length) {
        final path = widget.myHandCards[idx];
        final num = _cardNumber(path);
        if (num == 1) reduction += 1;
        if (num == 8 && widget.ecoCrisisType == 'climate') reduction += 1;
        if (num == 9 && widget.ecoCrisisType == 'ecology') reduction += 1;
        if (num == 10 && widget.ecoCrisisType == 'energy') reduction += 1;
      }
    }

    for (final item in _selectedTeammateCards.values) {
      final path = item['card'] ?? '';
      final num = _cardNumber(path);
      if (num == 1) reduction += 1;
      if (num == 8 && widget.ecoCrisisType == 'climate') reduction += 1;
      if (num == 9 && widget.ecoCrisisType == 'ecology') reduction += 1;
      if (num == 10 && widget.ecoCrisisType == 'energy') reduction += 1;
    }

    return reduction;
  }

  bool _hasAutoWinSelected() {
    for (final idx in _selectedMyCardIndices) {
      if (idx >= 0 && idx < widget.myHandCards.length && _cardNumber(widget.myHandCards[idx]) == 5) {
        return true;
      }
    }
    if (_selectedTeammateCards.values.any((item) => _cardNumber(item['card'] ?? '') == 5)) return true;
    return false;
  }

  bool _hasRerollSelected() {
    for (final idx in _selectedMyCardIndices) {
      if (idx >= 0 && idx < widget.myHandCards.length && _cardNumber(widget.myHandCards[idx]) == 6) {
        return true;
      }
    }
    if (_selectedTeammateCards.values.any((item) => _cardNumber(item['card'] ?? '') == 6)) return true;
    return false;
  }

  bool _hasAnyNumberWinsActive() {
    if (widget.anyNumberWins) return true;
    for (final idx in _selectedMyCardIndices) {
      if (idx >= 0 && idx < widget.myHandCards.length && _cardNumber(widget.myHandCards[idx]) == 7) {
        return true;
      }
    }
    if (_selectedTeammateCards.values.any((item) => _cardNumber(item['card'] ?? '') == 7)) return true;
    return false;
  }

  // Target efektif yang dihitung secara dinamis
  int _calculateEffectiveLevel() {
    final cardReduction = _calculateCardReduction();
    final totalRed = widget.baseDifficultyReduction +
        widget.characterPassiveReduction +
        widget.policymakerBuff +
        cardReduction;
    return (widget.currentEcoCrisisLevel - totalRed).clamp(1, 99);
  }

  bool _checkWillWin() {
    if (_hasAutoWinSelected()) return true;
    if (widget.spinResult == 'fail') return false;

    final spinNum = int.tryParse(widget.spinResult) ?? 0;
    if (_hasAnyNumberWinsActive() && widget.spinResult != 'fail') return true;

    final targetLevel = _calculateEffectiveLevel();
    return spinNum >= targetLevel;
  }

  void _toggleMyCard(int index) {
    setState(() {
      if (_selectedMyCardIndices.contains(index)) {
        _selectedMyCardIndices.remove(index);
      } else {
        _selectedMyCardIndices.add(index);
      }
    });
  }

  void _toggleTeammateCard(String key, String playerId, String card) {
    setState(() {
      if (_selectedTeammateCards.containsKey(key)) {
        _selectedTeammateCards.remove(key);
      } else {
        _selectedTeammateCards[key] = {
          'playerId': playerId,
          'card': card,
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isFail = widget.spinResult == 'fail';
    final spinNum = int.tryParse(widget.spinResult) ?? 0;

    final effectiveLevel = _calculateEffectiveLevel();
    final willWin = _checkWillWin();
    final hasReroll = _hasRerollSelected();
    final cardReduction = _calculateCardReduction();
    final gap = effectiveLevel - spinNum;

    // Filter kartu tangan sendiri yang relevan bersama indeks aslinya
    final helpfulMyCardIndices = <int>[];
    for (int i = 0; i < widget.myHandCards.length; i++) {
      if (_isCardHelpful(_cardNumber(widget.myHandCards[i]))) {
        helpfulMyCardIndices.add(i);
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: math.min(720.0, size.width * 0.94),
        constraints: BoxConstraints(maxHeight: size.height * 0.92),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── HEADER ─────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: _primaryGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(21),
                  topRight: Radius.circular(21),
                ),
              ),
              child: Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isMultiplayer
                              ? 'Keputusan Pasca Spin (Card Intervention)'
                              : 'Gunakan Kartu untuk Menang!',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.isMultiplayer
                              ? 'Gunakan kartu Anda atau bantuan teman untuk menurunkan level krisis!'
                              : 'Kamu ada kartu buat mengurangi level eco crisis dan menang, mau dipakai?',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(
                      const PostSpinDecision(isSkipped: true),
                    ),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE BODY ────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── STATUS PANEL ──────────────────────────────────────────
                    _buildStatusBanner(
                      isFail: isFail,
                      spinNum: spinNum,
                      effectiveLevel: effectiveLevel,
                      cardReduction: cardReduction,
                      gap: gap,
                      willWin: willWin,
                      hasReroll: hasReroll,
                    ),

                    const SizedBox(height: 14),

                    // ── BAGIAN KARTU ANDA ─────────────────────────────────────
                    _buildSectionHeader(
                      title: 'Kartu di Tangan Anda (${helpfulMyCardIndices.length} kartu relevan)',
                      icon: Icons.person_rounded,
                      color: _primaryGreen,
                    ),
                    const SizedBox(height: 8),
                    if (helpfulMyCardIndices.isEmpty)
                      _buildEmptyCardBox('Anda tidak memiliki kartu pengurang level saat ini.')
                    else
                      _buildCardGrid(
                        cardIndices: helpfulMyCardIndices,
                        isSelected: (origIdx) => _selectedMyCardIndices.contains(origIdx),
                        onTap: (origIdx) => _toggleMyCard(origIdx),
                      ),

                    const SizedBox(height: 16),

                    // ── BAGIAN KARTU DARI TEMAN (MULTIPLAYER) ──────────────────
                    if (widget.isMultiplayer) ...[
                      _buildSectionHeader(
                        title: 'Bantuan Kartu Teman (Teammate Support 🤝)',
                        icon: Icons.group_rounded,
                        color: const Color(0xFF38A3A5),
                      ),
                      const SizedBox(height: 8),
                      _buildTeammateSection(),
                    ],
                  ],
                ),
              ),
            ),

            // ── FOOTER BUTTONS ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(21),
                  bottomRight: Radius.circular(21),
                ),
                border: Border(
                  top: BorderSide(color: Colors.black.withOpacity(0.08), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  // Tombol Lewati
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(const PostSpinDecision(isSkipped: true));
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _cardBorder, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        'Lewati Tanpa Kartu',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol Terapkan / Reroll
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () {
                        final totalRed = _calculateCardReduction();
                        final autoWin = _hasAutoWinSelected();
                        final reroll = _hasRerollSelected();
                        final anyWins = _hasAnyNumberWinsActive();

                        final usedTeammates = _selectedTeammateCards.values.toList();
                        final usedMyCardsList = _selectedMyCardIndices
                            .map((i) => widget.myHandCards[i])
                            .toList();

                        Navigator.of(context).pop(
                          PostSpinDecision(
                            usedMyCards: usedMyCardsList,
                            usedTeammateCards: usedTeammates,
                            isReroll: reroll,
                            isAutoWin: autoWin,
                            totalDifficultyReduction: totalRed,
                            anyNumberWins: anyWins,
                            isSkipped: false,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: willWin || hasReroll ? _lightGreen : const Color(0xFFD4E5C6),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        side: const BorderSide(color: _cardBorder, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasReroll
                                ? Icons.refresh_rounded
                                : willWin
                                    ? Icons.check_circle_rounded
                                    : Icons.bolt_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasReroll
                                ? 'Gunakan & Reroll 🎲'
                                : willWin
                                    ? 'Gunakan Kartu & Menang! 🎉'
                                    : (_selectedMyCardIndices.isNotEmpty || _selectedTeammateCards.isNotEmpty)
                                        ? 'Gunakan Kartu Pilihan'
                                        : 'Selesaikan Giliran',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STATUS BANNER WIDGET ────────────────────────────────────────────────────
  Widget _buildStatusBanner({
    required bool isFail,
    required int spinNum,
    required int effectiveLevel,
    required int cardReduction,
    required int gap,
    required bool willWin,
    required bool hasReroll,
  }) {
    Color bannerBg;
    Color borderColor;
    String statusTitle;
    String statusSub;

    if (hasReroll) {
      bannerBg = const Color(0xFFE8F4F8);
      borderColor = const Color(0xFF2980B9);
      statusTitle = '🔄 KARTU REROLL AKTIF';
      statusSub = 'Putaran spin akan diulang kembali dengan roda baru!';
    } else if (willWin) {
      bannerBg = const Color(0xFFEAF5E9);
      borderColor = const Color(0xFF2E7D32);
      statusTitle = '🎉 TARGET TERPENUHI (WIN)!';
      statusSub = isFail
          ? 'Kartu Auto-Win menyelamatkan tim!'
          : 'Hasil spin $spinNum sudah mencapai target level $effectiveLevel!';
    } else if (isFail) {
      bannerBg = const Color(0xFFFDECEA);
      borderColor = const Color(0xFFC0392B);
      statusTitle = '❌ HASIL SPIN: FAIL';
      statusSub = 'Gunakan kartu Reroll (#6) atau Auto-Win (#5) jika ada untuk membalikkan hasil!';
    } else {
      bannerBg = const Color(0xFFFFF9E6);
      borderColor = const Color(0xFFF39C12);
      statusTitle = '⚠️ KURANG $gap POIN LAGI UNTUK MENANG!';
      statusSub = 'Gunakan kartu pengurang level krisis agar target turun ke <= $spinNum.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          // Spin Result Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isFail ? const Color(0xFFEB5757) : _primaryGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SPIN',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  isFail ? 'FAIL' : '$spinNum',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Target Breakdown & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: borderColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSub,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                // Kalkulasi Dinamis
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildCalcChip('Level Awal: ${widget.currentEcoCrisisLevel}', Colors.black54),
                    if (widget.baseDifficultyReduction > 0)
                      _buildCalcChip('Buff: -${widget.baseDifficultyReduction}', const Color(0xFF2980B9)),
                    if (widget.characterPassiveReduction > 0)
                      _buildCalcChip('Pasif: -${widget.characterPassiveReduction}', const Color(0xFF8E44AD)),
                    if (cardReduction > 0)
                      _buildCalcChip('Kartu: -$cardReduction', const Color(0xFF27AE60), isHighlighted: true),
                    _buildCalcChip('Target Baru: $effectiveLevel', Colors.black87, isBold: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcChip(String text, Color color, {bool isHighlighted = false, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF2ECC71).withOpacity(0.18) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF27AE60) : Colors.black12,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: isBold || isHighlighted ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── SECTION HEADER ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCardBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  // ── CARD GRID WIDGET ────────────────────────────────────────────────────────
  Widget _buildCardGrid({
    required List<int> cardIndices,
    required bool Function(int originalIdx) isSelected,
    required void Function(int originalIdx) onTap,
  }) {
    return SizedBox(
      height: 125,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cardIndices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final originalIdx = cardIndices[index];
          final path = widget.myHandCards[originalIdx];
          final num = _cardNumber(path);
          final selected = isSelected(originalIdx);

          return GestureDetector(
            onTap: () => onTap(originalIdx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 140,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFD4E5C6) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _primaryGreen : _cardBorder,
                  width: selected ? 2.5 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _primaryGreen.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          path,
                          width: 48,
                          height: 70,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cardTitle(num),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cardEffectDesc(num),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Checkmark badge
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: _primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TEAMMATE SECTION WIDGET ─────────────────────────────────────────────────
  Widget _buildTeammateSection() {
    final teammatesWithCards = widget.teammates.where((t) {
      return t.cards.any((c) => _isCardHelpful(_cardNumber(c)));
    }).toList();

    if (teammatesWithCards.isEmpty) {
      return _buildEmptyCardBox('Rekan tim saat ini tidak memiliki kartu pengurang krisis.');
    }

    return Column(
      children: teammatesWithCards.map((teammate) {
        final helpfulCards = teammate.cards.where((c) => _isCardHelpful(_cardNumber(c))).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teammate Header
              Row(
                children: [
                  const Icon(Icons.account_circle_rounded, size: 16, color: Color(0xFF38A3A5)),
                  const SizedBox(width: 6),
                  Text(
                    teammate.playerName,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  if (teammate.characterName.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38A3A5).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        teammate.characterName,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF38A3A5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Teammate Cards List
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: helpfulCards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final card = helpfulCards[idx];
                    final num = _cardNumber(card);
                    final key = '${teammate.playerId}|$card|$idx';
                    final isSelected = _selectedTeammateCards.containsKey(key);

                    return GestureDetector(
                      onTap: () => _toggleTeammateCard(key, teammate.playerId, card),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 130,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD0EDEB) : const Color(0xFFF9FBFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF38A3A5) : _cardBorder,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                card,
                                width: 36,
                                height: 55,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#$num Gunakan',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFF1E6F70) : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '(Kartu teman terpakai)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFC0392B),
                                    ),
                                  ),
                                  Text(
                                    _cardEffectDesc(num),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF38A3A5),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
