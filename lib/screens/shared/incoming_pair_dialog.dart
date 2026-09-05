import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

/// Shown on the *receiving* device when a peer asks to pair, with the
/// certificate fingerprint + address so the user can verify it (matches
/// the prototype's `pendingPair` panel).
class IncomingPairDialog extends StatelessWidget {
  const IncomingPairDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final req = state.pendingIncomingPair;
    if (req == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: const Color(0xAD0B0C14),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(22),
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 60, offset: Offset(0, 24))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.shieldPlus, size: 19, color: p.accent),
                  const SizedBox(width: 10),
                  Text(L.incoming, style: TextStyle(fontSize: 16, color: p.text)),
                ],
              ),
              const SizedBox(height: 13),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: req.name, style: TextStyle(color: p.text)),
                  TextSpan(text: ' ${L.incomingBody}', style: TextStyle(color: p.muted)),
                ]),
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'fingerprint SHA-256 · ${req.certFingerprint} · ${req.address}',
                  style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily, height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => state.answerIncomingPair(false),
                      style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.line), padding: const EdgeInsets.symmetric(vertical: 11)),
                      child: Text(L.decline, style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => state.answerIncomingPair(true),
                      style: ElevatedButton.styleFrom(backgroundColor: p.accentDim, foregroundColor: p.accent, side: BorderSide(color: p.accent), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11)),
                      child: Text(L.accept, style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
