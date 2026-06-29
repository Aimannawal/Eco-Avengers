import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class EcoAvengerLogo extends StatelessWidget {
  final double size;

  const EcoAvengerLogo({Key? key, this.size = 120}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PNG Logo (static) - prefer newly added logo in assets/logo/logo.png
        Container(
          width: size,
          height: size * 0.48,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/logo/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: size,
              height: size * 0.48,
              alignment: Alignment.center,
              child: Icon(
                Icons.eco_rounded,
                size: size * 0.5,
                color: AppColors.primaryDarkGreen,
              ),
            ),
          ),
        ),
        SizedBox(height: size > 150 ? 18 : 8),
        Text(
          'ECO AVENGER',
          style: AppTheme.titleLarge.copyWith(
            fontSize: size > 150 ? 36 : 28,
            color: AppColors.pureWhite,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: size > 150 ? 6 : 4),
        Text(
          'DEFEND THE PLANET. SECURE THE FUTURE.',
          style: AppTheme.subtitleRegular.copyWith(
            fontSize: size > 150 ? 13 : 11,
            color: AppColors.pureWhite,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
