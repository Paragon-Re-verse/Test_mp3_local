import 'package:flutter/material.dart';
import '../theme/nocturne_theme.dart';

/// The pill-shaped filter/sort chip used throughout the prototype (sort
/// options, tag filters, theme/colour/language segmented choices).
class ChipButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const ChipButton({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? p.accentDim : Colors.transparent,
          border: Border.all(color: active ? p.accent : p.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: active ? p.accent : p.muted),
        ),
      ),
    );
  }
}
