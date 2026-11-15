import 'package:flutter/material.dart';

/// SeeU logo: two stylised people on an indigo → violet gradient, with a pink check badge.
/// Also renders the launcher icons (tool/render_icon_test.dart). Drawn in a 512×512 space.
class SeeULogo extends StatelessWidget {
  const SeeULogo({super.key, this.size = 72, this.rounded = true, this.background = true, this.padding = 0});
  final double size;

  /// Rounded corners (false for launcher icons: the OS applies its own mask).
  final bool rounded;

  /// Gradient background (false for the Android adaptive-icon foreground).
  final bool background;

  /// Inner padding, in the 512 coordinate space (adaptive icons need a safe zone).
  final double padding;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(rounded: rounded, background: background, padding: padding)),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.rounded, required this.background, required this.padding});
  final bool rounded;
  final bool background;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    canvas.scale(s);
    final rect = const Rect.fromLTWH(0, 0, 512, 512);
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rounded ? 112 : 0)),
        Paint()..shader = const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF7C3AED)]).createShader(rect),
      );
    }
    final scale = (512 - 2 * padding) / 512;
    canvas.translate(padding, padding);
    canvas.scale(scale);
    final front = Paint()..color = Colors.white.withValues(alpha: 0.96);
    final back = Paint()..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawCircle(const Offset(196, 190), 62, front);
    canvas.drawPath(_body(86, 378, 110, 112, 392), front);
    canvas.drawCircle(const Offset(336, 208), 50, back);
    canvas.drawPath(_body(250, 392, 86, 94, 398), back);
    canvas.drawCircle(const Offset(388, 124), 34, Paint()..color = const Color(0xFFFB7185));
    canvas.drawPath(
      Path()
        ..moveTo(374, 118)
        ..lineTo(384, 128)
        ..lineTo(404, 108),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Rounded shoulders: from (x, y) an arc of half-width r up by h, down to the bottom line.
  Path _body(double x, double y, double r, double h, double bottom) {
    return Path()
      ..moveTo(x, y)
      ..cubicTo(x, y - 66 * h / 112, x + r - 60 * r / 110, y - h, x + r, y - h)
      ..cubicTo(x + r + 60 * r / 110, y - h, x + 2 * r, y - 66 * h / 112, x + 2 * r, y)
      ..lineTo(x + 2 * r, bottom)
      ..lineTo(x, bottom)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
