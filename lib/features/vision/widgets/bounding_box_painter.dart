import 'package:flutter/material.dart';
import '../services/ml_vision_service.dart';

/// CustomPainter untuk rendering kotak overlay panduan statis (Static Guide)
class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> detections;
  final Size screenSize;

  BoundingBoxPainter({required this.detections, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final boxWidth = screenSize.width * 0.65;
    final boxHeight = boxWidth * 1.2; 
    final left = (screenSize.width - boxWidth) / 2;
    final top = (screenSize.height - boxHeight) * 0.65;
    final staticRect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    // Ambil deteksi teratas
    BoundingBox? topDetection;
    bool isVerified = false;
    if (detections.isNotEmpty) {
      topDetection = detections.first;
      isVerified = topDetection.isVerified;
    }

    Color boxColor;
    if (isVerified) {
      boxColor = Colors.greenAccent;
    } else if (topDetection != null) {
      boxColor = const Color(0xFF06B6D4);
    } else {
      boxColor = Colors.white.withOpacity(0.4);
    }

    final paint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(staticRect, const Radius.circular(16)), 
      paint
    );

    // Gambar label jika ada deteksi
    if (topDetection != null) {
      _drawLabel(canvas, staticRect, topDetection);
    } else {
      _drawInstructionLabel(canvas, staticRect);
    }
  }

  void _drawInstructionLabel(Canvas canvas, Rect box) {
    const textSpan = TextSpan(
      text: " Posisikan tangan di sini ",
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
        backgroundColor: Colors.black54,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      box.left + (box.width - textPainter.width) / 2, 
      box.top - 24
    );

    textPainter.paint(canvas, offset);
  }

  void _drawLabel(Canvas canvas, Rect box, BoundingBox detection) {
    final percent = (detection.confidence * 100).toStringAsFixed(0);
    final textSpan = TextSpan(
      text: " ${detection.label} ($percent%) ",
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: detection.isVerified ? Colors.greenAccent : const Color(0xFF06B6D4),
        backgroundColor: Colors.black87,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Posisikan label di tengah atas kotak
    var offset = Offset(
      box.left + (box.width - textPainter.width) / 2, 
      box.top - 32
    );
    if (offset.dy < 0) offset = Offset(box.left + (box.width - textPainter.width) / 2, box.top + 8);

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}
