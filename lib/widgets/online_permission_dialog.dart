import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/network_permission_service.dart';
import 'retro_window.dart';

class OnlinePermissionDialog extends StatelessWidget {
  final VoidCallback? onGranted;
  final VoidCallback? onDenied;

  const OnlinePermissionDialog({
    Key? key,
    this.onGranted,
    this.onDenied,
  }) : super(key: key);

  static Future<bool> show(
    BuildContext context, {
    bool barrierDismissible = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => const OnlinePermissionDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: RetroWindow(
          title: 'Izin Akses Jaringan (Online)',
          titleIcon: Icons.wifi_rounded,
          onClose: () {
            Navigator.of(context).pop(false);
            onDenied?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC0C0C0),
                        border: Border(
                          top: BorderSide(color: Colors.black54, width: 2),
                          left: BorderSide(color: Colors.black54, width: 2),
                          bottom: BorderSide(color: Colors.white, width: 2),
                          right: BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_rounded, color: Color(0xFF2E7D32), size: 28),
                          SizedBox(width: 4),
                          Icon(Icons.cell_tower_rounded, color: Color(0xFF1565C0), size: 28),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IZIN PENGGUNAAN ONLINE',
                            style: GoogleFonts.vt323(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF000080),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Wi-Fi & Kuota Data Seluler',
                            style: GoogleFonts.vt323(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Explanation container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF808080), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Eco Avengers memerlukan izin untuk menggunakan koneksi internet (Wi-Fi atau Kuota Data Seluler) untuk:',
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBulletItem(
                        Icons.group_rounded,
                        'Bermain Multiplayer Realtime bersama pemain lain.',
                      ),
                      const SizedBox(height: 4),
                      _buildBulletItem(
                        Icons.leaderboard_rounded,
                        'Memperbarui skor dan peringkat Leaderboard.',
                      ),
                      const SizedBox(height: 4),
                      _buildBulletItem(
                        Icons.cloud_sync_rounded,
                        'Sinkronisasi akun dan progres permainan.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Badges row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureTag(Icons.wifi, 'Wi-Fi Aktif'),
                    _buildFeatureTag(Icons.data_usage_rounded, 'Kuota Data'),
                    _buildFeatureTag(Icons.lock_outline_rounded, 'Aman & Terenkripsi'),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildButton(
                      label: 'NANTI / OFFLINE',
                      isPrimary: false,
                      onTap: () {
                        NetworkPermissionService.instance.setPermissionGranted(false);
                        Navigator.of(context).pop(false);
                        onDenied?.call();
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildButton(
                      label: '✓ IZINKAN AKSES',
                      isPrimary: true,
                      onTap: () {
                        NetworkPermissionService.instance.setPermissionGranted(true);
                        Navigator.of(context).pop(true);
                        onGranted?.call();
                      },
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

  Widget _buildBulletItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2E86AB)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFB0B0B0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF404040)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.roboto(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF2E7D32) : const Color(0xFFC0C0C0),
          border: Border(
            top: BorderSide(
              color: isPrimary ? const Color(0xFF81C784) : Colors.white,
              width: 2,
            ),
            left: BorderSide(
              color: isPrimary ? const Color(0xFF81C784) : Colors.white,
              width: 2,
            ),
            bottom: BorderSide(
              color: isPrimary ? const Color(0xFF1B5E20) : Colors.black,
              width: 2,
            ),
            right: BorderSide(
              color: isPrimary ? const Color(0xFF1B5E20) : Colors.black,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.white : Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
