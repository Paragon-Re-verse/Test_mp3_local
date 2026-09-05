import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../state/app_screen.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/seek_bar.dart';
import '../../widgets/striped_cover.dart';

/// Full-screen "now playing" view, presented as an overlay above the
/// bottom-nav shell (mirrors the prototype's `position:absolute; inset:0;
/// z-index:5` song panel).
class SongScreen extends StatelessWidget {
  const SongScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final track = state.current;
    if (track == null) return const SizedBox.shrink();

    final total = Duration(seconds: track.durationSeconds);
    final progress = total.inMilliseconds == 0 ? 0.0 : state.position.inMilliseconds / total.inMilliseconds;

    return Positioned.fill(
      child: Container(
        color: p.bg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    _circleBtn(context, PhosphorIconsRegular.caretDown, state.closeSong),
                    Expanded(
                      child: Column(
                        children: [
                          Text(L.nowPlaying.toUpperCase(), style: TextStyle(fontSize: 9, letterSpacing: 1.8, color: p.muted, fontFamily: kMonoFamily)),
                          const SizedBox(height: 2),
                          Text('${state.curIndex + 1} ${L.of} ${state.queueIds.length}', style: TextStyle(fontSize: 11, color: p.accent, fontFamily: kMonoFamily)),
                        ],
                      ),
                    ),
                    _circleBtn(context, PhosphorIconsRegular.gearSix, () => state.openEdit(track.id)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 18))]),
                    child: StripedCover(hue: track.coverHue, radius: 12, imagePath: track.customCoverPath),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: TextStyle(fontSize: 21, color: p.text, letterSpacing: -0.2)),
                    const SizedBox(height: 4),
                    Text(track.artist, style: TextStyle(fontSize: 13, color: p.accent)),
                    const SizedBox(height: 2),
                    Text('${track.album}${track.tags.isEmpty ? '' : ' · ${track.tags.join(' · ')}'}', style: TextStyle(fontSize: 11.5, color: p.muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    SeekBar(progress: progress.clamp(0, 1), onSeek: state.seekFraction),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(Track.formatDuration(state.position.inSeconds), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                        Text(Track.formatDuration(track.durationSeconds), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(PhosphorIconsRegular.shuffle, size: 18, color: p.muted),
                    InkWell(onTap: state.prev, child: Icon(PhosphorIconsFill.skipBack, size: 22, color: p.text)),
                    InkWell(
                      onTap: state.toggleQ,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent), color: p.accentDim),
                        child: Icon(state.playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play, size: 26, color: p.accent),
                      ),
                    ),
                    InkWell(onTap: state.next, child: Icon(PhosphorIconsFill.skipForward, size: 22, color: p.text)),
                    Icon(PhosphorIconsRegular.repeat, size: 18, color: p.muted),
                  ],
                ),
              ),
              if (state.output == AudioOutput.peer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(border: Border.all(color: p.accent), borderRadius: BorderRadius.circular(8), color: p.accentDim),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsRegular.deviceMobileSpeaker, size: 16, color: p.accent),
                        const SizedBox(width: 9),
                        Text('${L.playingOnPhone} · ${state.paired?.name ?? ''}', style: TextStyle(fontSize: 12, color: p.accent)),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 17, color: p.text),
      ),
    );
  }
}
