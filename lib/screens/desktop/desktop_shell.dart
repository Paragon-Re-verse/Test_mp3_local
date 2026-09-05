import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../state/app_screen.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/seek_bar.dart';
import '../../widgets/striped_cover.dart';
import '../../widgets/toast_overlay.dart';
import '../phone/onboarding_screen.dart';
import '../shared/incoming_pair_dialog.dart';
import '../shared/sync_dialog.dart';
import '../shared/track_edit_sheet.dart';

/// Windows build: three-pane layout - library list (1/3), now-playing
/// centre, with the PC/Phone output switch and tag editor gear top-right.
/// Matches prototype panel 1b.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;

    if (state.screen == AppScreen.onboard) {
      return Scaffold(body: Center(child: SizedBox(width: 420, child: OnboardingScreen())));
    }

    final track = state.current;

    return Scaffold(
      body: ToastOverlay(
        bottom: 64,
        child: Stack(
          children: [
            Column(
              children: [
                _TitleBar(pcName: state.deviceName),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 320, child: _LibraryPane()),
                      VerticalDivider(width: 1, color: p.line),
                      Expanded(child: _NowPlayingPane(track: track)),
                    ],
                  ),
                ),
                _StatusBar(),
              ],
            ),
            if (state.pendingIncomingPair != null) const IncomingPairDialog(),
            if (state.editingTrack) const TrackEditSheet(desktop: true),
            if (state.syncPromptVisible) const SyncDialog(),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String pcName;
  const _TitleBar({required this.pcName});
  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(color: p.surface, border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.vinylRecord, size: 15, color: p.accent),
          const SizedBox(width: 10),
          Text('Локальный плеер', style: TextStyle(fontSize: 12, color: p.text)),
          const SizedBox(width: 8),
          Text('— $pcName', style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
          const Spacer(),
          SizedBox(width: 46, height: 38, child: Icon(PhosphorIconsRegular.minus, size: 13, color: p.muted)),
          SizedBox(width: 46, height: 38, child: Icon(PhosphorIconsRegular.square, size: 11, color: p.muted)),
          SizedBox(width: 46, height: 38, child: Icon(PhosphorIconsRegular.x, size: 13, color: p.muted)),
        ],
      ),
    );
  }
}

class _LibraryPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final list = state.visibleTracks;

    return Container(
      color: p.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(L.library, style: TextStyle(fontSize: 15, color: p.text)),
                    const SizedBox(width: 9),
                    Text('${list.length} ${L.tracks}', style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                    const Spacer(),
                    InkWell(
                      onTap: state.toggleSortDir,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(7)),
                        child: Row(children: [
                          Icon(state.sortDir == SortDir.asc ? PhosphorIconsRegular.sortAscending : PhosphorIconsRegular.sortDescending, size: 12, color: p.muted),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Row(
                    children: [
                      Icon(PhosphorIconsRegular.magnifyingGlass, size: 14, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: state.query)..selection = TextSelection.collapsed(offset: state.query.length),
                          onChanged: state.setQuery,
                          style: TextStyle(fontSize: 12, color: p.text),
                          decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: L.search, hintStyle: TextStyle(color: p.muted)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final isCur = state.current?.id == t.id;
                return InkWell(
                  onTap: () => state.play(t.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCur ? p.surface2 : Colors.transparent,
                      border: Border(bottom: BorderSide(color: p.line)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 34, height: 34, child: StripedCover(hue: t.coverHue, radius: 5, imagePath: t.customCoverPath)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.text)),
                              const SizedBox(height: 2),
                              Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: p.muted)),
                            ],
                          ),
                        ),
                        Text(Track.formatDuration(t.durationSeconds), style: TextStyle(fontSize: 10, color: p.muted, fontFamily: kMonoFamily)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingPane extends StatelessWidget {
  final Track? track;
  const _NowPlayingPane({required this.track});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    if (track == null) {
      return Center(child: Text(L.noTracks, style: TextStyle(color: p.muted)));
    }

    final total = Duration(seconds: track!.durationSeconds);
    final progress = total.inMilliseconds == 0 ? 0.0 : state.position.inMilliseconds / total.inMilliseconds;

    return Stack(
      children: [
        Positioned(
          top: 16,
          right: 18,
          child: Row(
            children: [
              _OutputSwitch(state: state, p: p),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => state.openEdit(track!.id),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                  child: Icon(PhosphorIconsRegular.gearSix, size: 16, color: p.text),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 290, height: 290, child: StripedCover(hue: track!.coverHue, radius: 14, imagePath: track!.customCoverPath)),
              const SizedBox(width: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(L.nowPlaying.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 2, color: p.accent, fontFamily: kMonoFamily)),
                    const SizedBox(height: 9),
                    Text(track!.title, style: TextStyle(fontSize: 34, color: p.text, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(track!.artist, style: TextStyle(fontSize: 15, color: p.text)),
                    const SizedBox(height: 4),
                    Text('${track!.album}${track!.year != null ? ' · ${track!.year}' : ''}${track!.tags.isEmpty ? '' : ' · ${track!.tags.join(' · ')}'}',
                        style: TextStyle(fontSize: 12, color: p.muted)),
                    const SizedBox(height: 12),
                    SeekBar(progress: progress.clamp(0, 1), onSeek: state.seekFraction, thumbSize: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(Track.formatDuration(state.position.inSeconds), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                        Text(Track.formatDuration(track!.durationSeconds), style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.shuffle, size: 16, color: p.muted),
                        const SizedBox(width: 14),
                        InkWell(onTap: state.prev, child: Icon(PhosphorIconsFill.skipBack, size: 20, color: p.text)),
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: state.toggleQ,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent), color: p.accentDim),
                            child: Icon(state.playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play, size: 22, color: p.accent),
                          ),
                        ),
                        const SizedBox(width: 14),
                        InkWell(onTap: state.next, child: Icon(PhosphorIconsFill.skipForward, size: 20, color: p.text)),
                        const SizedBox(width: 14),
                        Icon(PhosphorIconsRegular.repeat, size: 16, color: p.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutputSwitch extends StatelessWidget {
  final PlayerAppState state;
  final NocturnePalette p;
  const _OutputSwitch({required this.state, required this.p});

  @override
  Widget build(BuildContext context) {
    final isPhone = state.output == AudioOutput.peer;
    return Container(
      width: 186,
      height: 34,
      decoration: BoxDecoration(border: Border.all(color: p.line), color: p.surface, borderRadius: BorderRadius.circular(17)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOut,
            alignment: isPhone ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(decoration: BoxDecoration(color: p.accentDim, borderRadius: BorderRadius.circular(17))),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => state.setOutput(AudioOutput.local),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsRegular.desktopTower, size: 13, color: p.text),
                        const SizedBox(width: 6),
                        Text(state.L.pc, style: TextStyle(fontSize: 11.5, color: p.text)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => state.setOutput(AudioOutput.peer),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsRegular.deviceMobileSpeaker, size: 13, color: p.text),
                        const SizedBox(width: 6),
                        Text(state.L.phone, style: TextStyle(fontSize: 11.5, color: p.text)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Row(
        children: [
          if (state.paired != null) ...[
            Icon(PhosphorIconsRegular.shieldCheck, size: 14, color: p.accent),
            const SizedBox(width: 7),
            Text('${state.paired!.name} · ${L.secure}', style: TextStyle(fontSize: 11, color: p.accent)),
          ],
          if (state.output == AudioOutput.peer) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: p.accent), borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsRegular.waveform, size: 13, color: p.accent),
                const SizedBox(width: 7),
                Text(L.playingOnPhone, style: TextStyle(fontSize: 11, color: p.text)),
              ]),
            ),
          ],
          const Spacer(),
          if (state.queueIds.isNotEmpty)
            Text('${state.curIndex + 1} ${L.of} ${state.queueIds.length} · ${L.queue}', style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
        ],
      ),
    );
  }
}
