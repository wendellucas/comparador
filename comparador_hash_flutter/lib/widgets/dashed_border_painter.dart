import 'package:flutter/material.dart';

/// Desenha borda tracejada (quando o slot aguarda arquivo ou exibe erro) ou
/// borda contínua (durante carregamento, arraste ativo ou arquivo pronto).
class DropCardBorderPainter extends CustomPainter {
  const DropCardBorderPainter({
    required this.color,
    required this.dashed,
    this.strokeWidth = 2.0,
    this.radius = 14.0,
    this.dashWidth = 7.0,
    this.dashGap = 4.0,
  });

  final Color color;
  final bool dashed;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        (size.width - strokeWidth).clamp(0.0, double.infinity),
        (size.height - strokeWidth).clamp(0.0, double.infinity),
      ),
      Radius.circular(radius),
    );

    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DropCardBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashed != dashed ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
