import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renderiza o símbolo oficial da logo do aplicativo (escudo verificado em
/// dark slate `#0F172A` sobre cartão gradiente `#38BDF8` -> `#A78BFA`).
///
/// A geometria deste widget espelha exatamente os ícones e telas de splash
/// nativos gerados para Android, iOS, Web e Windows.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 42,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _AppLogoPainter(),
      ),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  const _AppLogoPainter();

  static const Color _darkSlate = Color(0xFF0F172A);
  static const Color _accentBlue = Color(0xFF38BDF8);
  static const Color _accentPurple = Color(0xFFA78BFA);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Offset.zero & Size(side, side);
    final cornerRadius = side * 0.24;

    // Fundo em gradiente diagonal azul -> roxo idêntico às áreas de Arquivo 1 e 2.
    final badgePaint = Paint()
      ..shader = const LinearGradient(
        colors: [_accentBlue, _accentPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final badgeRRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(badgeRRect, badgePaint);

    // Converte coordenadas normalizadas [-1, 1] para pixels do canvas.
    Offset pt(double u, double v) =>
        Offset(side * 0.5 + u * side * 0.5, side * 0.5 + v * side * 0.5);

    // Desenha o escudo central com ponta curva suave.
    final shieldPath = Path()
      ..moveTo(pt(0, -0.56).dx, pt(0, -0.56).dy)
      ..lineTo(pt(0.48, -0.36).dx, pt(0.48, -0.36).dy)
      ..lineTo(pt(0.48, 0.0).dx, pt(0.48, 0.0).dy)
      ..cubicTo(
        pt(0.48, 0.26).dx,
        pt(0.48, 0.26).dy,
        pt(0.24, 0.48).dx,
        pt(0.24, 0.48).dy,
        pt(0, 0.56).dx,
        pt(0, 0.56).dy,
      )
      ..cubicTo(
        pt(-0.24, 0.48).dx,
        pt(-0.24, 0.48).dy,
        pt(-0.48, 0.26).dx,
        pt(-0.48, 0.26).dy,
        pt(-0.48, 0.0).dx,
        pt(-0.48, 0.0).dy,
      )
      ..lineTo(pt(-0.48, -0.36).dx, pt(-0.48, -0.36).dy)
      ..close();

    // Usa saveLayer para recortar o checkmark interno revelando o gradiente de fundo.
    canvas.saveLayer(rect, Paint());
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = _darkSlate
        ..style = PaintingStyle.fill,
    );

    final checkPath = Path()
      ..moveTo(pt(-0.22, 0.01).dx, pt(-0.22, 0.01).dy)
      ..lineTo(pt(-0.05, 0.19).dx, pt(-0.05, 0.19).dy)
      ..lineTo(pt(0.25, -0.15).dx, pt(0.25, -0.15).dy);

    canvas.drawPath(
      checkPath,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = side * 0.136,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
