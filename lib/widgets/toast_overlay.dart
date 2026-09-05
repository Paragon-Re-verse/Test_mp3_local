import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/player_app_state.dart';
import '../theme/nocturne_theme.dart';

/// Wraps [child] in a Stack that shows the prototype's bottom toast
/// (`{{ hasToast }}`) whenever [PlayerAppState.toastMessage] is set.
class ToastOverlay extends StatelessWidget {
  final Widget child;
  final double bottom;
  const ToastOverlay({super.key, required this.child, this.bottom = 80});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final msg = context.select<PlayerAppState, String?>((s) => s.toastMessage);
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                  child: c,
                ),
              ),
              child: msg == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Align(
                      key: const ValueKey('toast'),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: p.surface2,
                          border: Border.all(color: p.line),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8))],
                        ),
                        child: Text(msg, style: TextStyle(fontSize: 12, color: p.text)),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
