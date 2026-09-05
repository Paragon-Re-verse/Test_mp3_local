import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

/// Custom colour picker: a hue ring plus a saturation/value triangle,
/// ported 1:1 from the prototype's ringAt/triAt pointer math (see
/// project/MP3 Local Player.dc.html) so the drag feel matches exactly.
class ColorPickerScreen extends StatelessWidget {
  const ColorPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    return Positioned.fill(
      child: Container(
        color: p.bg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    InkWell(
                      onTap: state.closeColorPicker,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                        child: Icon(PhosphorIconsRegular.caretLeft, size: 15, color: p.text),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(L.pickColor, style: TextStyle(fontSize: 16, color: p.text)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HueTriPicker(state: state),
                      const SizedBox(height: 18),
                      Container(
                        width: 240,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Container(width: 34, height: 34, decoration: BoxDecoration(color: colorFromHex(state.pickerHex), borderRadius: BorderRadius.circular(8))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L.preview.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: p.muted, fontFamily: kMonoFamily)),
                                  const SizedBox(height: 2),
                                  Text(state.pickerHex, style: TextStyle(fontSize: 13.5, color: p.text, fontFamily: kMonoFamily)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 230,
                        child: Text(L.pickHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.muted, height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.closeColorPicker,
                        style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.line), padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(L.cancel, style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.acceptColor,
                        style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: colorFromHex(state.pickerHex)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(L.accept, style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HueTriPicker extends StatelessWidget {
  final PlayerAppState state;
  const _HueTriPicker({required this.state});

  static const _ringSize = 240.0;
  static const _triBox = 188.0; // inner square the triangle math is defined over
  static const _triA = Offset(94, 6);
  static const _triB = Offset(17.8, 138);
  static const _triC = Offset(170.2, 138);

  void _handleRing(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final d = local - c;
    final deg = (math.atan2(d.dy, d.dx) * 180 / math.pi + 450) % 360;
    state.setHueFromAngle(deg);
  }

  void _handleTriangle(Offset local, Size size) {
    final px = local.dx / size.width * _triBox;
    final py = local.dy / size.height * _triBox;
    final den = (_triB.dy - _triC.dy) * (_triA.dx - _triC.dx) + (_triC.dx - _triB.dx) * (_triA.dy - _triC.dy);
    var wA = ((_triB.dy - _triC.dy) * (px - _triC.dx) + (_triC.dx - _triB.dx) * (py - _triC.dy)) / den;
    var wB = ((_triC.dy - _triA.dy) * (px - _triC.dx) + (_triA.dx - _triC.dx) * (py - _triC.dy)) / den;
    wA = math.max(0, wA);
    wB = math.max(0, wB);
    var wC = math.max(0, 1 - wA - wB);
    final t = (wA + wB + wC) == 0 ? 1 : (wA + wB + wC);
    wA /= t;
    wB /= t;
    final v = ((wA + wB).clamp(0.02, 1.0));
    final s = (wA + wB) > 0 ? (wA / (wA + wB)).clamp(0.0, 1.0) : 0.0;
    state.setSatValFromTriangle(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, state.pickerHue, 1, 1).toColor();
    final markerColor = colorFromHex(state.pickerHex);
    final triPos = Offset(
      (state.pickerSat * state.pickerVal * _triA.dx + state.pickerVal * (1 - state.pickerSat) * _triB.dx + (1 - state.pickerVal) * _triC.dx) / _triBox,
      (state.pickerSat * state.pickerVal * _triA.dy + state.pickerVal * (1 - state.pickerSat) * _triB.dy + (1 - state.pickerVal) * _triC.dy) / _triBox,
    );

    return SizedBox(
      width: _ringSize,
      height: _ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onPanDown: (d) => _handleRing(d.localPosition, const Size(_ringSize, _ringSize)),
            onPanUpdate: (d) => _handleRing(d.localPosition, const Size(_ringSize, _ringSize)),
            child: Container(
              width: _ringSize,
              height: _ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(colors: [
                  Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
                ]),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 34, offset: Offset(0, 12))],
              ),
              child: Align(
                alignment: Alignment(math.cos((state.pickerHue - 90) * math.pi / 180), math.sin((state.pickerHue - 90) * math.pi / 180)),
                child: Container(
                  width: 16,
                  height: 28,
                  decoration: BoxDecoration(color: hueColor, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            ),
          ),
          Container(
            width: _ringSize - 52,
            height: _ringSize - 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).extension<NocturnePalette>()!.bg),
            child: Center(
              child: GestureDetector(
                onPanDown: (d) => _handleTriangle(d.localPosition, const Size(188, 188)),
                onPanUpdate: (d) => _handleTriangle(d.localPosition, const Size(188, 188)),
                child: SizedBox(
                  width: 188,
                  height: 188,
                  child: Stack(
                    children: [
                      CustomPaint(size: const Size(188, 188), painter: _TrianglePainter(hueColor)),
                      Positioned(
                        left: triPos.dx * 188 - 9,
                        top: triPos.dy * 188 - 9,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: markerColor, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color hueColor;
  _TrianglePainter(this.hueColor);

  @override
  void paint(Canvas canvas, Size size) {
    const a = Offset(94, 6);
    const b = Offset(17.8, 138);
    const c = Offset(170.2, 138);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = hueColor);
    // White gradient from the white corner (b) toward the hue corner (a).
    final whiteGrad = Paint()
      ..shader = ui.Gradient.linear(b, a, [Colors.white, Colors.white.withValues(alpha: 0)]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), whiteGrad);
    // Black gradient from the black corner (c) toward the hue corner (a).
    final blackGrad = Paint()
      ..shader = ui.Gradient.linear(c, a, [Colors.black, Colors.black.withValues(alpha: 0)]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blackGrad);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.hueColor != hueColor;
}
