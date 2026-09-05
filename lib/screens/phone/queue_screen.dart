import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/striped_cover.dart';

/// "Hold a track to reorder" queue screen. Matches the prototype's
/// pointer-down-for-300ms gesture: holding reveals up/down/remove/done
/// controls in place of the row's normal content.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    return Container(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(L.queue, style: TextStyle(fontSize: 24, color: p.text, letterSpacing: -0.2)),
                      const SizedBox(width: 10),
                      if (state.queueIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('${state.curIndex + 1} ${L.of} ${state.queueIds.length}',
                              style: TextStyle(fontSize: 11, color: p.muted, fontFamily: kMonoFamily)),
                        ),
                      const Spacer(),
                      if (state.queueIds.isNotEmpty)
                        TextButton(
                          onPressed: state.clearQueue,
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: Text(L.clearQueue, style: TextStyle(color: p.accent, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(L.holdHint, style: TextStyle(fontSize: 11.5, color: p.muted, height: 1.4)),
                ],
              ),
            ),
            Expanded(
              child: state.queueIds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(L.queueEmpty, style: TextStyle(color: p.muted, fontSize: 12.5)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: state.addAllToQueue,
                            style: OutlinedButton.styleFrom(foregroundColor: p.accent, side: BorderSide(color: p.accent)),
                            child: Text(L.addAll),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: state.queueIds.length,
                      itemBuilder: (context, i) => _QueueRow(index: i, trackId: state.queueIds[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final int index;
  final String trackId;
  const _QueueRow({required this.index, required this.trackId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final track = state.trackById(trackId);
    if (track == null) return const SizedBox.shrink();
    final isCur = index == state.curIndex;
    final moving = state.moveId == trackId;
    final bg = moving ? p.accentDim : (isCur ? p.surface2 : Colors.transparent);

    return Listener(
      onPointerDown: (_) => state.startHold(trackId),
      onPointerUp: (_) => state.cancelHold(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: [
            SizedBox(width: 16, child: Text(index.toString().padLeft(2, '0'), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily))),
            const SizedBox(width: 11),
            SizedBox(width: 36, height: 36, child: StripedCover(hue: track.coverHue, radius: 6, imagePath: track.customCoverPath)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.text)),
                  const SizedBox(height: 2),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.muted)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: moving
                  ? Row(
                      key: const ValueKey('moving'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundBtn(context, PhosphorIconsRegular.arrowUp, () => state.moveQueue(index, -1), accent: true),
                        const SizedBox(width: 4),
                        _roundBtn(context, PhosphorIconsRegular.arrowDown, () => state.moveQueue(index, 1), accent: true),
                        const SizedBox(width: 4),
                        _roundBtn(context, PhosphorIconsRegular.x, () => state.removeFromQueue(trackId)),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: state.endMove,
                          style: TextButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.bg, minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                          child: Text(state.L.done, style: const TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('static'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCur) _EqBars(color: p.accent),
                        const SizedBox(width: 8),
                        Text(Track.formatDuration(track.durationSeconds), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(BuildContext context, IconData icon, VoidCallback onTap, {bool accent = false}) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(border: Border.all(color: accent ? p.accent : p.line), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: accent ? p.accent : p.muted),
      ),
    );
  }
}

class _EqBars extends StatefulWidget {
  final Color color;
  const _EqBars({required this.color});
  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final phase = (_controller.value + i / 3) * 2 * math.pi;
              final h = 0.2 + 0.7 * (0.5 - 0.5 * math.cos(phase));
              return Container(width: 2, height: h * 14, color: widget.color);
            }),
          );
        },
      ),
    );
  }
}
