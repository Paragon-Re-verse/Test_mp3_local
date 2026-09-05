import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cover art. Prefers a real embedded/custom cover image; otherwise draws
/// the prototype's diagonal-stripe placeholder, colour-keyed by [hue] (same
/// `repeating-linear-gradient(135deg, oklch(...))` trick as the dc.html).
class StripedCover extends StatelessWidget {
  final int hue;
  final double radius;
  final String? imagePath;

  const StripedCover({super.key, required this.hue, this.radius = 8, this.imagePath});

  @override
  Widget build(BuildContext context) {
    final child = (imagePath != null && File(imagePath!).existsSync())
        ? Image.file(File(imagePath!), fit: BoxFit.cover)
        : CustomPaint(painter: _StripePainter(hue), child: const SizedBox.expand());
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

class _StripePainter extends CustomPainter {
  final int hue;
  _StripePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final a = HSVColor.fromAHSV(1, hue.toDouble(), 0.35, 0.42).toColor();
    final b = HSVColor.fromAHSV(1, hue.toDouble(), 0.4, 0.32).toColor();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = b);
    final stripeWidth = 7.0;
    final diag = size.width + size.height;
    final paintA = Paint()..color = a;
    canvas.save();
    canvas.rotate(135 * math.pi / 180);
    for (double x = -diag; x < diag * 2; x += stripeWidth * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, stripeWidth, diag * 3), paintA);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) => oldDelegate.hue != hue;
}
