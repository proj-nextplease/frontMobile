import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'design.dart';

/// Tấm nền neon mesh phát sáng tương tự HeroMesh trên webapp (nextplease.online).
///
/// Phối hợp các quầng sáng cyan (#2DD4BF) và neon lime/emerald (#B9FF00) với
/// độ nhòe (blur) cao và lớp vignette phủ tối để tạo chiều sâu neon hiện đại.
class NeonMeshBackground extends StatelessWidget {
  const NeonMeshBackground({
    super.key,
    this.height = 420,
    this.opacity = 0.65,
  });

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: opacity,
            child: const CustomPaint(
              painter: _NeonMeshPainter(),
            ),
          ),
          // Lớp vignette làm mờ dần xuống màu nền ink (#070A0F) ở đáy
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF070A0F).withValues(alpha: 0.2),
                    const Color(0xFF070A0F).withValues(alpha: 0.75),
                    const Color(0xFF070A0F),
                  ],
                  stops: const [0.0, 0.45, 0.78, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonMeshPainter extends CustomPainter {
  const _NeonMeshPainter();

  static const _cyan = Color(0xFF2DD4BF);
  static const _emerald = Color(0xFFB9FF00);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50)
      ..style = PaintingStyle.fill;

    // Quầng 1: Cyan trên bên trái
    paint.shader = ui.Gradient.radial(
      Offset(size.width * 0.18, size.height * 0.12),
      size.width * 0.45,
      [
        _cyan.withValues(alpha: 0.38),
        _cyan.withValues(alpha: 0.12),
        Colors.transparent,
      ],
      [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.12),
      size.width * 0.45,
      paint,
    );

    // Quầng 2: Cyan trên bên phải
    paint.shader = ui.Gradient.radial(
      Offset(size.width * 0.82, size.height * 0.08),
      size.width * 0.42,
      [
        _cyan.withValues(alpha: 0.32),
        _cyan.withValues(alpha: 0.08),
        Colors.transparent,
      ],
      [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.08),
      size.width * 0.42,
      paint,
    );

    // Quầng 3: Neon Emerald/Lime chính giữa bên trái
    paint.shader = ui.Gradient.radial(
      Offset(size.width * 0.32, size.height * 0.42),
      size.width * 0.52,
      [
        _emerald.withValues(alpha: 0.34),
        _emerald.withValues(alpha: 0.10),
        Colors.transparent,
      ],
      [0.0, 0.60, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.42),
      size.width * 0.52,
      paint,
    );

    // Quầng 4: Neon Emerald/Lime bên phải
    paint.shader = ui.Gradient.radial(
      Offset(size.width * 0.78, size.height * 0.48),
      size.width * 0.44,
      [
        _emerald.withValues(alpha: 0.28),
        _emerald.withValues(alpha: 0.06),
        Colors.transparent,
      ],
      [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.48),
      size.width * 0.44,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget bọc nền neon mesh phát sáng chuẩn nextplease.
class NeonBackground extends StatelessWidget {
  const NeonBackground({
    super.key,
    required this.child,
    this.meshHeight = 500,
    this.meshOpacity = 0.70,
  });

  final Widget child;
  final double meshHeight;
  final double meshOpacity;

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    return Material(
      color: c.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NeonMeshBackground(
              height: meshHeight,
              opacity: meshOpacity,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
