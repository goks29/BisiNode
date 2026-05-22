import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logbook_app_001/features/vision/camera_viewport.dart';
import 'package:logbook_app_001/features/vision/models/translation_log.dart';
import 'package:logbook_app_001/features/vision/widgets/translation_history_view.dart';

/// Halaman utama BISINDO Edge Translator
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  int get _totalTranslations {
    try {
      return Hive.box<TranslationLog>('translation_logs').length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131315),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              const Text(
                "BISINDO",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF06B6D4),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Edge Translator",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Terjemahkan bahasa isyarat Indonesia secara real-time menggunakan kamera perangkat Anda.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white38,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Tombol utama: Mulai Terjemahkan
              _buildMainAction(
                context,
                icon: Icons.camera_alt_rounded,
                title: "Mulai Terjemahkan",
                subtitle: "Buka kamera untuk mendeteksi bahasa isyarat",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraViewport()),
                ),
              ),

              const SizedBox(height: 16),

              // Tombol kedua: Riwayat Terjemahan
              _buildMainAction(
                context,
                icon: Icons.history_rounded,
                title: "Riwayat Terjemahan",
                subtitle: "$_totalTranslations huruf terdeteksi",
                accentColor: const Color(0xFF8B5CF6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TranslationHistoryView()),
                ),
              ),

              const Spacer(),

              // Info bar di bawah
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x331F1F21),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A06B6D4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white24, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Mendukung 2 mode deteksi: Huruf dan Angka.",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color accentColor = const Color(0xFF06B6D4),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accentColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
