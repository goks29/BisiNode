import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'vision_controller.dart';
import 'services/ml_vision_service.dart';
import 'widgets/bounding_box_painter.dart';

/// Tampilan utama kamera BISINDO Edge Translator
class CameraViewport extends StatefulWidget {
  const CameraViewport({super.key});

  @override
  State<CameraViewport> createState() => _CameraViewportState();
}

class _CameraViewportState extends State<CameraViewport> {
  late final VisionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VisionController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildModeChip(String label, ModelType type) {
    final isSelected = _controller.currentModelType == type;
    return GestureDetector(
      onTap: () => _controller.switchModel(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06B6D4) : const Color(0x991F1F21),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0x3306B6D4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131315),
      appBar: AppBar(
        title: const Text(
          "BISINDO Lens",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F21),
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: Icon(
              _controller.isFlashlightOn ? Icons.flash_on : Icons.flash_off,
              color: const Color(0xFF06B6D4),
            ),
            onPressed: () async {
              await _controller.toggleFlashlight();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF06B6D4)),
            onPressed: () => Navigator.pushNamed(context, '/riwayat'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              // === Area Kamera (proporsional, tidak gepeng) ===
              Expanded(child: _buildCameraSection()),

              // === Panel Terjemahan (compact, fixed height) ===
              _buildTranslationPanel(),
            ],
          );
        },
      ),
    );
  }

  /// Area kamera dengan bounding box & kontrol overlay
  Widget _buildCameraSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Kamera Preview
        if (_controller.isInitialized && _controller.cameraController != null)
          CameraPreview(_controller.cameraController!)
        else
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
          ),

        // 2. Bounding Box Overlay
        if (_controller.detections.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final cameraSize = Size(constraints.maxWidth, constraints.maxHeight);
              return CustomPaint(
                size: cameraSize,
                painter: BoundingBoxPainter(
                  detections: _controller.detections,
                  screenSize: cameraSize,
                ),
              );
            },
          ),

        // Loading overlay saat switching model
        if (_controller.isSwitchingModel)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  SizedBox(height: 12),
                  Text(
                    "Memuat model...",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Progress bar verifikasi
        Positioned(
          top: 12,
          left: 60,
          right: 60,
          child: AnimatedOpacity(
            opacity: _controller.consecutiveProgress > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _controller.consecutiveProgress,
                backgroundColor: Colors.white.withOpacity(0.15),
                color: Colors.greenAccent,
                minHeight: 4,
              ),
            ),
          ),
        ),

        // 4. Model Selector (Huruf & Angka saja)
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeChip("Huruf", ModelType.alphabet),
              const SizedBox(width: 12),
              _buildModeChip("Angka", ModelType.numbers),
            ],
          ),
        ),

        // 5. Tombol Flip Kamera
        Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: () => _controller.flipCamera(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xCC1F1F21),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x3306B6D4)),
              ),
              child: const Icon(
                Icons.cameraswitch_rounded,
                color: Color(0xFF06B6D4),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Panel terjemahan compact di bawah kamera
  Widget _buildTranslationPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1C),
        border: Border(
          top: BorderSide(color: Color(0x1A06B6D4), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header + teks hasil
          Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF06B6D4), size: 16),
              const SizedBox(width: 6),
              const Text(
                "TERJEMAHAN",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Teks hasil deteksi
          Text(
            _controller.assembledWord.isEmpty
                ? "Mulai peragakan bahasa isyarat..."
                : _controller.assembledWord,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _controller.assembledWord.isEmpty
                  ? Colors.white30
                  : Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Kontrol teks
          Row(
            children: [
              _buildActionButton(
                icon: Icons.space_bar,
                label: "Spasi",
                onTap: _controller.addSpace,
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                label: "Hapus",
                onTap: _controller.backspace,
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.delete_forever,
                label: "Clear",
                onTap: _controller.clearText,
                color: const Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF06B6D4),
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
