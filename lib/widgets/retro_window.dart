import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroWindow extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final VoidCallback? onBack;
  final IconData? titleIcon;

  const RetroWindow({
    Key? key,
    required this.title,
    required this.child,
    this.onClose,
    this.onBack,
    this.titleIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0), // Classic Win95 Gray
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inner Bevel Top
          Container(
            height: 2,
            color: Colors.white,
          ),
          Row(
            children: [
              Container(
                width: 2,
                color: Colors.white,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title Bar
                    Container(
                      margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0000AA), // Classic Win95 Title Blue
                      ),
                      child: Row(
                        children: [
                          if (onBack != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onBack,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.yellowAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            )
                          else if (titleIcon != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                titleIcon,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.vt323(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          if (onClose != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onClose,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFC0C0C0),
                                    border: Border(
                                      top: BorderSide(color: Colors.white, width: 2),
                                      left: BorderSide(color: Colors.white, width: 2),
                                      bottom: BorderSide(color: Colors.black, width: 2),
                                      right: BorderSide(color: Colors.black, width: 2),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'X',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Main Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                color: const Color(0xFF808080),
              ),
            ],
          ),
          // Inner Bevel Bottom
          Container(
            height: 2,
            color: const Color(0xFF808080),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show a standard Windows 95 / Retro styled alert dialog
Future<void> showRetroAlertDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String? cancelLabel,
  IconData icon = Icons.info_outline,
  Color iconColor = const Color(0xFF0000AA),
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool barrierDismissible = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: RetroWindow(
          title: title,
          titleIcon: icon,
          onClose: () {
            Navigator.of(ctx).pop();
            onCancel?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC0C0C0),
                        border: Border(
                          top: BorderSide(color: Colors.black54, width: 2),
                          left: BorderSide(color: Colors.black54, width: 2),
                          bottom: BorderSide(color: Colors.white, width: 2),
                          right: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.vt323(
                          fontSize: 20,
                          color: Colors.black87,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelLabel != null) ...[
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onCancel?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC0C0C0),
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 2),
                              left: BorderSide(color: Colors.white, width: 2),
                              bottom: BorderSide(color: Colors.black, width: 2),
                              right: BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            style: GoogleFonts.vt323(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onConfirm?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC0C0C0),
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 2),
                            left: BorderSide(color: Colors.white, width: 2),
                            bottom: BorderSide(color: Colors.black, width: 2),
                            right: BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: GoogleFonts.vt323(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
