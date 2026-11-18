import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Gezeichneter Hintergrund im Anime-Stil: Straße in Fluchtperspektive,
/// Himmel mit Sonne/Mond, Strommasten, Laternen, nasse Straße.
/// Jeder [variant] ergibt eine andere Tageszeit und eine andere Straße.
class AnimeScene extends StatelessWidget {
  const AnimeScene({super.key, required this.variant});

  final int variant;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ScenePainter(variant),
        size: Size.infinite,
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.sky,
    required this.stops,
    required this.sun,
    required this.glow,
    required this.cloudLit,
    required this.cloudDark,
    required this.building,
    required this.buildingEdge,
    required this.window,
    required this.stars,
    required this.isNight,
  });

  final List<Color> sky;
  final List<double> stops;
  final Color sun;
  final Color glow;
  final Color cloudLit;
  final Color cloudDark;
  final Color building;
  final Color buildingEdge;
  final List<Color> window;
  final int stars;
  final bool isNight;
}

const _palettes = <_Palette>[
  // Sonnenuntergang
  _Palette(
    sky: [Color(0xFF1A1340), Color(0xFF4A2477), Color(0xFFC63E6B), Color(0xFFFF7A3D), Color(0xFFFFC36A)],
    stops: [0, 0.22, 0.48, 0.66, 0.8],
    sun: Color(0xFFFFF0C2),
    glow: Color(0xFFFF9A4A),
    cloudLit: Color(0xFFFF8F5A),
    cloudDark: Color(0xFF6B2F6E),
    building: Color(0xFF1C1430),
    buildingEdge: Color(0xFF3A2148),
    window: [Color(0xFFFFC874), Color(0xFFFF9E5E), Color(0xFFFFE1A8)],
    stars: 25,
    isNight: false,
  ),
  // Nacht
  _Palette(
    sky: [Color(0xFF03061A), Color(0xFF0C1740), Color(0xFF1E2F6B), Color(0xFF4B4C8F), Color(0xFF8B6FA8)],
    stops: [0, 0.3, 0.55, 0.72, 0.82],
    sun: Color(0xFFF5F1DC),
    glow: Color(0xFF8FA3FF),
    cloudLit: Color(0xFF6F78B8),
    cloudDark: Color(0xFF1A2152),
    building: Color(0xFF0A0D20),
    buildingEdge: Color(0xFF1A2046),
    window: [Color(0xFFFFD27A), Color(0xFF9FE3FF), Color(0xFFFF8FB0)],
    stars: 160,
    isNight: true,
  ),
  // Roter Sonnenuntergang
  _Palette(
    sky: [Color(0xFF241650), Color(0xFF6E2A86), Color(0xFFE0435C), Color(0xFFFF6A2B), Color(0xFFFFB347)],
    stops: [0, 0.25, 0.5, 0.68, 0.8],
    sun: Color(0xFFFFF4D0),
    glow: Color(0xFFFF7A35),
    cloudLit: Color(0xFFFF6B4A),
    cloudDark: Color(0xFF5A2470),
    building: Color(0xFF221433),
    buildingEdge: Color(0xFF4A2246),
    window: [Color(0xFFFFB866), Color(0xFFFF8A5C), Color(0xFFFFD99A)],
    stars: 30,
    isNight: false,
  ),
  // Blaue Stunde / Dämmerung
  _Palette(
    sky: [Color(0xFF0E1A3D), Color(0xFF2B3A7A), Color(0xFF7D56A3), Color(0xFFE6798A), Color(0xFFFFB38A)],
    stops: [0, 0.28, 0.5, 0.68, 0.8],
    sun: Color(0xFFFFE6C8),
    glow: Color(0xFFFF8E9E),
    cloudLit: Color(0xFFF08AA0),
    cloudDark: Color(0xFF3B3477),
    building: Color(0xFF141A36),
    buildingEdge: Color(0xFF2A2E5C),
    window: [Color(0xFFFFCF7D), Color(0xFFFFA9C2), Color(0xFFBFE8FF)],
    stars: 70,
    isNight: false,
  ),
  // Morgen
  _Palette(
    sky: [Color(0xFF27407A), Color(0xFF5E73B8), Color(0xFFB59AD0), Color(0xFFF7B4A8), Color(0xFFFFE2B8)],
    stops: [0, 0.3, 0.52, 0.68, 0.8],
    sun: Color(0xFFFFFBEA),
    glow: Color(0xFFFFD39A),
    cloudLit: Color(0xFFFFD0C0),
    cloudDark: Color(0xFF7A78B5),
    building: Color(0xFF232646),
    buildingEdge: Color(0xFF3D4170),
    window: [Color(0xFFFFE3A6), Color(0xFFFFFFFF), Color(0xFFFFC9A0)],
    stars: 0,
    isNight: false,
  ),
];

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.variant);

  final int variant;

  // Kamera / Perspektive
  static const _eye = 1.6; // Augenhöhe über der Straße
  static const _focal = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _palettes[variant % _palettes.length];
    final rnd = Random(variant * 7919 + 13);
    final w = size.width;
    final h = size.height;
    final vp = Offset(w * 0.5, h * 0.6); // Fluchtpunkt
    final scale = w * 0.42;

    Offset proj(double x, double y, double z) =>
        Offset(vp.dx + x / z * _focal * scale, vp.dy + y / z * _focal * scale);

    // ---------- Himmel ----------
    final skyRect = Offset.zero & size;
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, vp.dy),
          p.sky,
          p.stops.map((s) => (s / 0.8).clamp(0.0, 1.0)).toList(),
        ),
    );

    // Sterne
    final starPaint = Paint()..color = Colors.white;
    for (var i = 0; i < p.stars; i++) {
      final sx = rnd.nextDouble() * w;
      final sy = pow(rnd.nextDouble(), 1.6) * vp.dy * 0.85;
      final r = rnd.nextDouble() * (p.isNight ? 1.4 : 0.9) + 0.3;
      starPaint.color =
          Colors.white.withValues(alpha: 0.35 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(Offset(sx, sy.toDouble()), r, starPaint);
    }

    // Sonne / Mond am Ende der Straße
    final sunCenter = p.isNight
        ? Offset(w * (0.68 + rnd.nextDouble() * 0.12), h * 0.2)
        : Offset(vp.dx + (rnd.nextDouble() - 0.5) * w * 0.08, vp.dy - h * 0.045);
    final sunR = w * (p.isNight ? 0.09 : 0.11);
    canvas.drawCircle(
      sunCenter,
      sunR * 5,
      Paint()
        ..shader = ui.Gradient.radial(sunCenter, sunR * 5, [
          p.glow.withValues(alpha: 0.55),
          p.glow.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(sunCenter, sunR, Paint()..color = p.sun);
    if (p.isNight) {
      // Mondsichel-Schatten
      canvas.drawCircle(
        sunCenter + Offset(sunR * 0.45, -sunR * 0.2),
        sunR * 0.92,
        Paint()..color = p.sky[1].withValues(alpha: 0.85),
      );
    }

    // ---------- Wolken ----------
    for (var i = 0; i < 9; i++) {
      final cy = vp.dy * (0.12 + rnd.nextDouble() * 0.7);
      final cx = rnd.nextDouble() * w;
      final cw = w * (0.35 + rnd.nextDouble() * 0.6);
      final ch = h * (0.012 + rnd.nextDouble() * 0.025);
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);
      final lit = cy > vp.dy * 0.3 || rnd.nextBool();
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(ch)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [
              (lit ? Color.lerp(p.cloudDark, p.cloudLit, 0.5)! : p.cloudDark)
                  .withValues(alpha: 0.8),
              (lit ? p.cloudLit : p.cloudDark).withValues(alpha: 0.95),
            ],
          ),
      );
    }

    // Ferne Skyline am Horizont
    final farPaint = Paint()..color = Color.lerp(p.building, p.sky[3], 0.45)!;
    var fx = vp.dx - w * 0.22;
    while (fx < vp.dx + w * 0.22) {
      final bw = w * (0.015 + rnd.nextDouble() * 0.03);
      final bh = h * (0.01 + rnd.nextDouble() * 0.05);
      canvas.drawRect(Rect.fromLTWH(fx, vp.dy - bh, bw, bh + 2), farPaint);
      fx += bw * 0.9;
    }

    // ---------- Straße (nass, spiegelnd) ----------
    final roadPath = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(vp.dx + 2, vp.dy)
      ..lineTo(vp.dx - 2, vp.dy)
      ..close();
    canvas.drawRect(
      Rect.fromLTRB(0, vp.dy, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, vp.dy),
          Offset(0, h),
          [p.sky[4], p.glow, p.sky[2], Color.lerp(p.sky[1], p.building, 0.5)!],
          [0, 0.1, 0.4, 1],
        ),
    );
    // Spiegelung der Sonne
    canvas.save();
    canvas.clipPath(roadPath);
    final streak = Rect.fromLTRB(
        sunCenter.dx - sunR * 0.9, vp.dy, sunCenter.dx + sunR * 0.9, h);
    canvas.drawRect(
      streak,
      Paint()
        ..shader = ui.Gradient.linear(
          streak.topCenter,
          streak.bottomCenter,
          [p.sun, p.glow.withValues(alpha: 0.0)],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Pfützen-Glanzlinien
    final shine = Paint()
      ..color = p.glow.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 40; i++) {
      final z = 1.2 + rnd.nextDouble() * 18;
      final x = (rnd.nextDouble() - 0.5) * 5.2;
      final a = proj(x, _eye, z);
      final b = proj(x + 0.4 + rnd.nextDouble(), _eye, z);
      canvas.drawLine(a, b, shine);
    }
    canvas.restore();

    // Bordsteine
    final curb = Paint()
      ..color = p.buildingEdge.withValues(alpha: 0.9)
      ..strokeWidth = 2;
    canvas.drawLine(proj(-2.6, _eye, 0.6), proj(-2.6, _eye, 60), curb);
    canvas.drawLine(proj(2.6, _eye, 0.6), proj(2.6, _eye, 60), curb);

    // ---------- Gebäude links & rechts ----------
    for (final side in [-1.0, 1.0]) {
      var z = 0.55;
      final blocks = <({double z0, double z1, double hgt, double inset})>[];
      while (z < 40) {
        final len = 1.5 + rnd.nextDouble() * 4;
        blocks.add((
          z0: z,
          z1: z + len,
          hgt: 3 + rnd.nextDouble() * 9,
          inset: rnd.nextDouble() * 0.6,
        ));
        z += len;
      }
      // von hinten nach vorne zeichnen
      for (final b in blocks.reversed) {
        final x = side * (3.0 + b.inset);
        final top = _eye - b.hgt;
        final facade = Path()
          ..moveTo(proj(x, _eye, b.z0).dx, proj(x, _eye, b.z0).dy)
          ..lineTo(proj(x, top, b.z0).dx, proj(x, top, b.z0).dy)
          ..lineTo(proj(x, top, b.z1).dx, proj(x, top, b.z1).dy)
          ..lineTo(proj(x, _eye, b.z1).dx, proj(x, _eye, b.z1).dy)
          ..close();
        final shade = (b.z0 / 40).clamp(0.0, 1.0);
        canvas.drawPath(
          facade,
          Paint()..color = Color.lerp(p.building, p.sky[3], shade * 0.55)!,
        );
        // Vorderkante (zur Straße hin) – Dachlinie hell
        canvas.drawLine(
          proj(x, top, b.z0),
          proj(x, top, b.z1),
          Paint()
            ..color = p.glow.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
        // Stirnseite des Blocks
        final front = Path()
          ..moveTo(proj(x, _eye, b.z0).dx, proj(x, _eye, b.z0).dy)
          ..lineTo(proj(x, top, b.z0).dx, proj(x, top, b.z0).dy)
          ..lineTo(proj(side * 9, top, b.z0).dx, proj(side * 9, top, b.z0).dy)
          ..lineTo(proj(side * 9, _eye, b.z0).dx, proj(side * 9, _eye, b.z0).dy)
          ..close();
        canvas.drawPath(front, Paint()..color = p.building);

        // Fenster
        final floors = (b.hgt / 1.1).floor();
        final cols = (b.z1 - b.z0) ~/ 0.9;
        for (var f = 1; f < floors; f++) {
          for (var c = 0; c < cols; c++) {
            if (rnd.nextDouble() > (p.isNight ? 0.45 : 0.3)) continue;
            final wz0 = b.z0 + 0.25 + c * 0.9;
            final wz1 = wz0 + 0.45;
            final wy0 = _eye - f * 1.1;
            final wy1 = wy0 + 0.55;
            final win = Path()
              ..moveTo(proj(x, wy0, wz0).dx, proj(x, wy0, wz0).dy)
              ..lineTo(proj(x, wy1, wz0).dx, proj(x, wy1, wz0).dy)
              ..lineTo(proj(x, wy1, wz1).dx, proj(x, wy1, wz1).dy)
              ..lineTo(proj(x, wy0, wz1).dx, proj(x, wy0, wz1).dy)
              ..close();
            final col = p.window[rnd.nextInt(p.window.length)];
            canvas.drawPath(
                win,
                Paint()
                  ..color = col.withValues(
                      alpha: (0.55 + rnd.nextDouble() * 0.45) * (1 - shade * 0.6)));
          }
        }
      }
    }

    // ---------- Strommasten & Leitungen ----------
    final polePaint = Paint()
      ..color = Color.lerp(p.building, Colors.black, 0.35)!
      ..strokeCap = StrokeCap.round;
    final wirePaint = Paint()
      ..color = Color.lerp(p.building, Colors.black, 0.2)!.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final poleH = 7.5;
    for (final side in [-1.0, 1.0]) {
      final x = side * 2.4;
      final zs = <double>[1.4, 3.6, 7.0, 12.0, 19.0, 30.0];
      final tops = <Offset>[];
      for (final z in zs) {
        final base = proj(x, _eye, z);
        final top = proj(x, _eye - poleH, z);
        polePaint.strokeWidth = max(1.0, w * 0.018 / z);
        canvas.drawLine(base, top, polePaint);
        // Querträger
        final armL = proj(x - 0.5, _eye - poleH + 0.4, z);
        final armR = proj(x + 0.5, _eye - poleH + 0.4, z);
        polePaint.strokeWidth = max(0.8, w * 0.01 / z);
        canvas.drawLine(armL, armR, polePaint);
        tops.add(top);
      }
      // Leitungen zwischen den Masten (durchhängend)
      for (var line = 0; line < 3; line++) {
        final dy = line * 0.35;
        final path = Path();
        for (var i = 0; i < zs.length; i++) {
          final pt = proj(x + (line - 1) * 0.45, _eye - poleH + 0.4 + dy, zs[i]);
          if (i == 0) {
            final start = proj(x + (line - 1) * 0.45, _eye - poleH + 0.4 + dy, 0.35);
            path.moveTo(start.dx, start.dy);
          }
          final prev = i == 0
              ? proj(x + (line - 1) * 0.45, _eye - poleH + 0.4 + dy, 0.35)
              : proj(x + (line - 1) * 0.45, _eye - poleH + 0.4 + dy, zs[i - 1]);
          final mid = Offset((prev.dx + pt.dx) / 2,
              (prev.dy + pt.dy) / 2 + (pt - prev).distance * 0.08);
          path.quadraticBezierTo(mid.dx, mid.dy, pt.dx, pt.dy);
        }
        canvas.drawPath(path, wirePaint);
      }
      // Leitungen quer über die Straße
      if (side > 0) {
        for (final z in [3.6, 12.0]) {
          final a = proj(-2.4, _eye - poleH + 0.4, z);
          final b = proj(2.4, _eye - poleH + 0.4, z);
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + (b - a).distance * 0.07);
          canvas.drawPath(
              Path()
                ..moveTo(a.dx, a.dy)
                ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
              wirePaint);
        }
      }
    }

    // ---------- Laternen ----------
    final lanternColor = p.isNight ? const Color(0xFFFF5A4E) : const Color(0xFFE8463F);
    for (final l in [
      (x: 2.75, y: _eye - 3.2, z: 2.2),
      (x: -2.85, y: _eye - 2.8, z: 4.5),
      (x: 2.8, y: _eye - 2.9, z: 7.5),
    ]) {
      final c = proj(l.x, l.y, l.z);
      final r = w * 0.09 / l.z;
      canvas.drawCircle(
        c,
        r * 3,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 3, [
            lanternColor.withValues(alpha: 0.45),
            lanternColor.withValues(alpha: 0),
          ]),
      );
      final body = Rect.fromCenter(center: c, width: r * 1.6, height: r * 2.1);
      canvas.drawOval(
        body,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 1.2, [
            const Color(0xFFFFC2A0),
            lanternColor,
          ]),
      );
    }

    // Leichter Dunst über dem Horizont
    canvas.drawRect(
      Rect.fromLTRB(0, vp.dy - h * 0.06, w, vp.dy + h * 0.04),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, vp.dy - h * 0.06),
          Offset(0, vp.dy + h * 0.04),
          [
            p.glow.withValues(alpha: 0),
            p.glow.withValues(alpha: 0.22),
            p.glow.withValues(alpha: 0),
          ],
          [0, 0.6, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.variant != variant;
}
