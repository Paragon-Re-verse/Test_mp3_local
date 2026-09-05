import 'package:flutter/material.dart';
import '../theme/nocturne_theme.dart';

/// Thin progress rail with a round thumb, matching the prototype's
/// `.dv` progress track. [progress] is 0..1; the fill/thumb animate
/// linearly to the new position (the prototype's `transition: width 1s
/// linear` / `left 1s linear`).
class SeekBar extends StatelessWidget {
  final double progress;
  final ValueChanged<double> onSeek;
  final double thumbSize;

  const SeekBar({super.key, required this.progress, required this.onSeek, this.thumbSize = 11});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onSeek((d.localPosition.dx / width).clamp(0, 1)),
        onHorizontalDragUpdate: (d) => onSeek((d.localPosition.dx / width).clamp(0, 1)),
        child: SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 3, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 280),
                curve: Curves.linear,
                widthFactor: progress.clamp(0, 1),
                alignment: Alignment.centerLeft,
                child: Container(height: 3, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.linear,
                alignment: Alignment(progress.clamp(0, 1) * 2 - 1, 0),
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
