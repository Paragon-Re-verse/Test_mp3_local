import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

/// First-run "choose your music folder" screen. The prototype mocked a
/// fake file browser here (design tools can't touch the real filesystem);
/// the real app instead opens the platform's native directory picker
/// directly, which is the correct real-world behaviour for the same intent.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    return Container(
      color: p.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: p.accent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(PhosphorIconsRegular.folderOpen, color: p.accent, size: 22),
              ),
              const SizedBox(height: 18),
              Text(
                L.onbKicker.toUpperCase(),
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: p.accent, fontFamily: kMonoFamily, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(L.onbTitle, style: TextStyle(fontSize: 26, height: 1.2, color: p.text, letterSpacing: -0.2)),
              const SizedBox(height: 10),
              Text(L.onbBody, style: TextStyle(fontSize: 13, height: 1.6, color: p.muted)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.pickFolder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.accentDim,
                    foregroundColor: p.accent,
                    side: BorderSide(color: p.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(L.choose, style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(PhosphorIconsRegular.lockSimple, size: 13, color: p.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(L.secure, style: TextStyle(fontSize: 11, color: p.muted))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
