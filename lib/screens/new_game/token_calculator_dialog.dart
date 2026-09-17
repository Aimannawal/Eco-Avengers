import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class TokenCalculatorDialog extends StatefulWidget {
  final String tokenType; // 'energy', 'peace', 'crisis'
  final int baseValue;
  final List<ActionCard> availableCards;
  final VoidCallback? onApply;

  const TokenCalculatorDialog({
    Key? key,
    required this.tokenType,
    required this.baseValue,
    required this.availableCards,
    this.onApply,
  }) : super(key: key);

  @override
  State<TokenCalculatorDialog> createState() => _TokenCalculatorDialogState();
}

class _TokenCalculatorDialogState extends State<TokenCalculatorDialog> {
  late List<ActionCard> selectedCards;
  late int totalValue;

  @override
  void initState() {
    super.initState();
    selectedCards = [];
    totalValue = widget.baseValue;
  }

  void _toggleCard(ActionCard card) {
    setState(() {
      final index =
          selectedCards.indexWhere((c) => c.id == card.id);
      if (index >= 0) {
        selectedCards.removeAt(index);
      } else {
        selectedCards.add(card);
      }
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    int newTotal = widget.baseValue;
    for (final card in selectedCards) {
      for (final effect in card.effects) {
        if (effect.tokenType.toLowerCase() == widget.tokenType.toLowerCase()) {
          newTotal += effect.modifier;
        }
      }
    }
    totalValue = newTotal.clamp(0, 999).toInt();
  }

  Color _getTokenColor() {
    switch (widget.tokenType.toLowerCase()) {
      case 'energy':
        return const Color(0xFFF39C12);
      case 'peace':
        return const Color(0xFF3498DB);
      case 'crisis':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _getTokenLabel() {
    return widget.tokenType[0].toUpperCase() +
        widget.tokenType.substring(1).toLowerCase();
  }

  List<ActionCard> _getCardsWithEffect() {
    return widget.availableCards
        .where((card) => card.effects.any(
              (effect) =>
                  effect.tokenType.toLowerCase() ==
                  widget.tokenType.toLowerCase(),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokenColor = _getTokenColor();
    final tokenLabel = _getTokenLabel();
    final cardsWithEffect = _getCardsWithEffect();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF111111), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$tokenLabel Calculator',
                      style: AppTheme.titleMedium.copyWith(
                        fontSize: 22,
                        color: tokenColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Current calculation display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tokenColor.withOpacity(0.15),
                        tokenColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokenColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Base value
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Base Value',
                            style: AppTheme.subtitleRegular.copyWith(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tokenColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.baseValue}',
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 16,
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Calculation details if cards selected
                      if (selectedCards.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(
                          color: tokenColor.withOpacity(0.2),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        // Show each selected card's effect
                        ...selectedCards.map((card) {
                          final effect = card.effects.firstWhere(
                            (e) =>
                                e.tokenType.toLowerCase() ==
                                widget.tokenType.toLowerCase(),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    card.title,
                                    style: AppTheme.captionText.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: effect.modifier < 0
                                        ? const Color(0xFFE74C3C)
                                        : const Color(0xFF2ECC71),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${effect.modifier > 0 ? '+' : ''}${effect.modifier}',
                                    style: AppTheme.captionText.copyWith(
                                      fontSize: 11,
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],

                      // Total value
                      const SizedBox(height: 12),
                      Divider(
                        color: tokenColor.withOpacity(0.2),
                        height: 1,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: AppTheme.subtitleRegular.copyWith(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tokenColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: tokenColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '$totalValue',
                              style: AppTheme.titleMedium.copyWith(
                                fontSize: 24,
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Available cards section
                if (cardsWithEffect.isNotEmpty) ...[
                  Text(
                    'Select Cards to Apply',
                    style: AppTheme.subtitleRegular.copyWith(
                      fontSize: 14,
                      color: AppColors.primaryDarkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cards grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: cardsWithEffect.length,
                    itemBuilder: (context, index) {
                      final card = cardsWithEffect[index];
                      final isSelected = selectedCards
                          .any((c) => c.id == card.id);
                      final effect = card.effects.firstWhere(
                        (e) =>
                            e.tokenType.toLowerCase() ==
                            widget.tokenType.toLowerCase(),
                      );

                      return GestureDetector(
                        onTap: () => _toggleCard(card),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? card.color.withOpacity(0.2)
                                : AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? card.color
                                  : card.color.withOpacity(0.3),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: card.color.withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Card title
                                    Expanded(
                                      child: Text(
                                        card.title,
                                        style: AppTheme.subtitleRegular
                                            .copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: card.color,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Effect badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: effect.modifier < 0
                                            ? const Color(0xFFE74C3C)
                                            : const Color(0xFF2ECC71),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${effect.modifier > 0 ? '+' : ''}${effect.modifier} $tokenLabel',
                                        style:
                                            AppTheme.captionText.copyWith(
                                          fontSize: 10,
                                          color: AppColors.pureWhite,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Selection indicator
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: card.color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
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
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            AppColors.textSecondary.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'No cards available for $tokenLabel',
                      textAlign: TextAlign.center,
                      style: AppTheme.subtitleSmall.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.textSecondary.withOpacity(
                                0.2,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: AppTheme.subtitleRegular.copyWith(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: selectedCards.isEmpty
                            ? null
                            : () {
                                widget.onApply?.call();
                                Navigator.pop(context);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedCards.isEmpty
                                ? AppColors.textSecondary.withOpacity(0.3)
                                : tokenColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: selectedCards.isNotEmpty
                                ? [
                                    BoxShadow(
                                      color:
                                          tokenColor.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            'Apply Effect',
                            textAlign: TextAlign.center,
                            style: AppTheme.subtitleRegular.copyWith(
                              fontSize: 14,
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}
