import 'package:flutter/material.dart';
import '../services/ml_vision_service.dart';

/// CustomPainter untuk rendering kotak overlay deteksi (SRP)
class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> detections;
  final Size screenSize;

  BoundingBoxPainter({required this.detections, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (var detection in detections) {
      // Deteksi apakah koordinat model bersifat normalized (0..1) atau absolute (0..inputSize)
      // Jika <= 1.0, berarti normalized, kalikan langsung dengan screenSize.
      // Jika > 1.0, berarti absolute, skalakan dari 640 ke screenSize.
      final isNormalized = detection.rect.right <= 1.0 && detection.rect.bottom <= 1.0;

      final scaleX = isNormalized ? screenSize.width : (screenSize.width / 640.0);
      final scaleY = isNormalized ? screenSize.height : (screenSize.height / 640.0);

      final scaledRect = Rect.fromLTRB(
        detection.rect.left * scaleX,
        detection.rect.top * scaleY,
        detection.rect.right * scaleX,
        detection.rect.bottom * scaleY,
      );

      // Electric Cyan default, Hijau jika terverifikasi > 2 detik
      final paint = Paint()
        ..color = detection.isVerified
            ? Colors.greenAccent
            : const Color(0xFF06B6D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRect(scaledRect, paint);
      _drawLabel(canvas, scaledRect, detection);
    }
  }

  void _drawLabel(Canvas canvas, Rect box, BoundingBox detection) {
    final percent = (detection.confidence * 100).toStringAsFixed(0);
    final textSpan = TextSpan(
      text: "${detection.label} ($percent%)",
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        backgroundColor: Colors.black87,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Smart positioning: di dalam box jika posisi atas melebihi layar
    var offset = Offset(box.left, box.top - 20);
    if (offset.dy < 0) offset = Offset(box.left, box.top + 5);

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}
