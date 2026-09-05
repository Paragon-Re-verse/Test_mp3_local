import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

/// "Sync with PC?" confirmation, shown after saving a tag edit while paired
/// (unless the "don't ask again for this device" box was previously
/// checked). Matches the prototype's syncPhone/syncPc panels.
class SyncDialog extends StatelessWidget {
  const SyncDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    return Positioned.fill(
      child: Container(
        color: const Color(0xB30B0C14),
        padding: const EdgeInsets.all(22),
        alignment: Alignment.center,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 50, offset: Offset(0, 20))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.arrowsLeftRight, size: 17, color: p.accent),
                  const SizedBox(width: 9),
                  Text(L.syncTitle, style: TextStyle(fontSize: 15, color: p.text)),
                ],
              ),
              const SizedBox(height: 12),
              Text('${L.syncBody} ${state.paired?.name ?? ''}.', style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.55)),
              const SizedBox(height: 12),
              InkWell(
                onTap: state.toggleDontAskDraft,
                child: Row(
                  children: [
                    Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: state.dontAskDraft ? p.accent : Colors.transparent,
                        border: state.dontAskDraft ? null : Border.all(color: p.line),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: state.dontAskDraft ? Icon(PhosphorIconsRegular.check, size: 11, color: p.bg) : null,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(L.dontAsk, style: TextStyle(fontSize: 11.5, color: p.muted, height: 1.45))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => state.syncAnswer(false),
                      style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.line), padding: const EdgeInsets.symmetric(vertical: 11)),
                      child: Text(L.no, style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => state.syncAnswer(true),
                      style: ElevatedButton.styleFrom(backgroundColor: p.accentDim, foregroundColor: p.accent, side: BorderSide(color: p.accent), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11)),
                      child: Text(L.yes, style: const TextStyle(fontSize: 12.5)),
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
