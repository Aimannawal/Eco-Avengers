import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class TokenReferenceDialog extends StatelessWidget {
  const TokenReferenceDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(24),
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
                      'Token Reference',
                      style: AppTheme.titleMedium.copyWith(
                        fontSize: 24,
                        color: AppColors.primaryDarkGreen,
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

                // Token descriptions
                _buildTokenInfo(
                  'Energy',
                  'Represents your action capacity and ability to solve climate issues. Used to reduce difficulty levels on crisis cards. Higher energy means you can tackle more complex problems.',
                  const Color(0xFFF39C12),
                ),
                const SizedBox(height: 16),
                _buildTokenInfo(
                  'Peace',
                  'Represents community cooperation and resilience. Used to stabilize regions and prevent crisis escalation. More peace helps communities adapt to changes better.',
                  const Color(0xFF3498DB),
                ),
                const SizedBox(height: 16),
                _buildTokenInfo(
                  'Planetary Crisis',
                  'Represents the global environmental threat level. If this reaches the end of the board, the game is lost. Every failed action moves this token forward, increasing planetary danger.',
                  const Color(0xFFE74C3C),
                ),
                const SizedBox(height: 20),

                // How tokens work section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryDarkGreen.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How Tokens Work',
                        style: AppTheme.subtitleRegular.copyWith(
                          fontSize: 14,
                          color: AppColors.primaryDarkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStepItem(
                        '1',
                        'Select Action Cards to reduce difficulty on climate issues.',
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem(
                        '2',
                        'Click token counters to calculate total effects from your cards.',
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem(
                        '3',
                        'Roll the dice to resolve climate challenges.',
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem(
                        '4',
                        'Success moves you forward; failure advances the crisis.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Strategy tip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2ECC71).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: const Color(0xFF2ECC71),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pro Tip',
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF2ECC71),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Balance your token usage carefully. Every action has consequences - choose your cards wisely to maximize success!',
                              style: AppTheme.captionText.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDarkGreen.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Understood',
                      textAlign: TextAlign.center,
                      style: AppTheme.subtitleRegular.copyWith(
                        fontSize: 15,
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.w700,
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
  }

  Widget _buildTokenInfo(String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with colored dot
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.subtitleRegular.copyWith(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            description,
            style: AppTheme.subtitleSmall.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryDarkGreen,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTheme.subtitleRegular.copyWith(
                fontSize: 12,
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: AppTheme.subtitleSmall.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
