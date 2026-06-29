import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PlayerCard extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool highlight;

  const PlayerCard({
    Key? key,
    required this.rank,
    required this.name,
    required this.score,
    this.highlight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withOpacity(highlight ? 0.06 : 0.03),
            blurRadius: highlight ? 12 : 6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.secondaryGreen.withOpacity(0.14),
            child: Text(name[0], style: AppTheme.titleMedium.copyWith(fontSize: 18, color: AppColors.primaryDarkGreen)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.subtitleRegular.copyWith(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Rank #$rank', style: AppTheme.captionText.copyWith(fontSize: 13, color: AppColors.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score', style: AppTheme.titleMedium.copyWith(fontSize: 18, color: AppColors.primaryDarkGreen, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }
}
