import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String? characterAsset;
  final double radius;
  final double borderWidth;
  final Color borderColor;
  final Color backgroundColor;
  final double? fontSize;

  const UserAvatar({
    Key? key,
    this.avatarUrl,
    required this.name,
    this.characterAsset,
    this.radius = 24.0,
    this.borderWidth = 2.0,
    this.borderColor = const Color(0xFF111111),
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.fontSize,
  }) : super(key: key);

  String get _initial {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  bool get _hasAvatarUrl => avatarUrl != null && avatarUrl!.isNotEmpty;
  bool get _hasCharacter => characterAsset != null && characterAsset!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        image: _hasAvatarUrl
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : (_hasCharacter
                ? DecorationImage(
                    image: AssetImage(characterAsset!),
                    fit: BoxFit.cover,
                  )
                : null),
      ),
      child: (!_hasAvatarUrl && !_hasCharacter)
          ? Center(
              child: Text(
                _initial,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize ?? (radius * 0.9),
                  color: Colors.black54,
                ),
              ),
            )
          : null,
    );
  }
}
