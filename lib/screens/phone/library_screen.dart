import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../state/app_screen.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/striped_cover.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final list = state.visibleTracks;
    final hasFilter = state.tagFilter.isNotEmpty || state.query.isNotEmpty;

    const sortEntries = [
      (SortKey.title, 'title'),
      (SortKey.artist, 'artist'),
      (SortKey.album, 'album'),
      (SortKey.duration, 'duration'),
      (SortKey.tags, 'tags'),
    ];
    String labelFor(SortKey k) => switch (k) {
          SortKey.title => L.title,
          SortKey.artist => L.artist,
          SortKey.album => L.album,
          SortKey.duration => L.duration,
          SortKey.tags => L.tags,
        };

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
                      Text(L.library, style: TextStyle(fontSize: 24, color: p.text, letterSpacing: -0.2)),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('${list.length} / ${state.tracks.length}',
                            style: TextStyle(fontSize: 11, color: p.muted, fontFamily: kMonoFamily)),
                      ),
                      const Spacer(),
                      _iconButton(context, PhosphorIconsRegular.gearSix, () => state.nav(AppScreen.settings)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border.all(color: p.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsRegular.magnifyingGlass, size: 15, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: state.query)
                              ..selection = TextSelection.collapsed(offset: state.query.length),
                            onChanged: state.setQuery,
                            style: TextStyle(fontSize: 13, color: p.text),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: L.search,
                              hintStyle: TextStyle(color: p.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tonalButton(context, PhosphorIconsRegular.funnel, L.filters, state.toggleFilterOpen),
                      const SizedBox(width: 8),
                      _tonalButton(
                        context,
                        state.sortDir == SortDir.asc ? PhosphorIconsRegular.sortAscending : PhosphorIconsRegular.sortDescending,
                        labelFor(state.sortKey),
                        state.toggleSortDir,
                        muted: true,
                      ),
                      const Spacer(),
                      if (hasFilter)
                        TextButton(
                          onPressed: state.resetFilter,
                          child: Text(L.reset, style: TextStyle(color: p.accent, fontSize: 12)),
                        ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: !state.filterOpen
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(L.sort.toUpperCase(),
                                    style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, color: p.muted, fontFamily: kMonoFamily)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: sortEntries
                                      .map((e) => ChipButton(
                                            label: labelFor(e.$1),
                                            active: state.sortKey == e.$1,
                                            onTap: () => state.setSortKey(e.$1),
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 10),
                                Text(L.tags.toUpperCase(),
                                    style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, color: p.muted, fontFamily: kMonoFamily)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: state.allTags
                                      .map((t) => ChipButton(
                                            label: t,
                                            active: state.tagFilter.contains(t),
                                            onTap: () => state.toggleTagFilter(t),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.scanningLibrary
                  ? Center(child: CircularProgressIndicator(color: p.accent))
                  : list.isEmpty
                      ? Center(child: Text(L.noTracks, style: TextStyle(color: p.muted, fontSize: 12.5)))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) => _TrackRow(track: list[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 17, color: p.muted),
      ),
    );
  }

  Widget _tonalButton(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool muted = false}) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: muted ? p.muted : p.text),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: muted ? p.muted : p.text)),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final Track track;
  const _TrackRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final state = context.read<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: () => state.openSong(track.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: StripedCover(hue: track.coverHue, radius: 6, imagePath: track.customCoverPath)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.text)),
                  const SizedBox(height: 3),
                  Text('${track.artist} · ${track.album}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.muted)),
                ],
              ),
            ),
            Text(Track.formatDuration(track.durationSeconds), style: TextStyle(fontSize: 11, color: p.muted, fontFamily: kMonoFamily)),
          ],
        ),
      ),
    );
  }
}
