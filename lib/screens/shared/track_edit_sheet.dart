import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/striped_cover.dart';

/// Track-properties editor. Phone presents it as a bottom sheet, desktop as
/// a centered modal - same content either way (title/artist/album/cover
/// upload/tag toggles), matching the prototype's editPhone/editPc panels.
class TrackEditSheet extends StatelessWidget {
  final bool desktop;
  const TrackEditSheet({super.key, this.desktop = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final draft = state.draft;
    if (draft == null) return const SizedBox.shrink();
    final track = state.trackById(draft.trackId);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(L.editTitle, style: TextStyle(fontSize: 16, color: p.text))),
            InkWell(
              onTap: state.closeEdit,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(7)),
                child: Icon(PhosphorIconsRegular.x, size: 14, color: p.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: desktop ? 120 : 64,
              height: desktop ? 120 : 64,
              child: StripedCover(hue: track?.coverHue ?? 0, imagePath: draft.newCoverPath ?? track?.customCoverPath),
            ),
            const SizedBox(width: 14),
            if (!desktop)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(L.cover, style: TextStyle(fontSize: 11.5, color: p.muted)),
                  const SizedBox(height: 6),
                  _uploadButton(context, state, p, L.upload),
                  if (draft.newCoverPath != null) ...[
                    const SizedBox(height: 4),
                    Text('cover-custom', style: TextStyle(fontSize: 10.5, color: p.accent, fontFamily: kMonoFamily)),
                  ],
                ],
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(context, hint: L.title, value: draft.title, onChanged: state.updateDraftTitle),
                    const SizedBox(height: 9),
                    _field(context, hint: L.artist, value: draft.artist, onChanged: state.updateDraftArtist),
                    const SizedBox(height: 9),
                    _field(context, hint: L.album, value: draft.album, onChanged: state.updateDraftAlbum),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: state.allTags
                          .map((t) => ChipButton(label: t, active: draft.tags.contains(t), onTap: () => state.toggleDraftTag(t)))
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (!desktop) ...[
          const SizedBox(height: 14),
          _field(context, hint: L.title, value: draft.title, onChanged: state.updateDraftTitle),
          const SizedBox(height: 9),
          _field(context, hint: L.artist, value: draft.artist, onChanged: state.updateDraftArtist),
          const SizedBox(height: 9),
          _field(context, hint: L.album, value: draft.album, onChanged: state.updateDraftAlbum),
          const SizedBox(height: 12),
          Text(L.tagsOn, style: TextStyle(fontSize: 11.5, color: p.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: state.allTags.map((t) => ChipButton(label: t, active: draft.tags.contains(t), onTap: () => state.toggleDraftTag(t))).toList(),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: desktop ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!desktop) ...[
              Expanded(child: _outlineBtn(context, L.cancel, state.closeEdit)),
              const SizedBox(width: 9),
              Expanded(child: _filledBtn(context, L.save, state.commitEdit)),
            ] else ...[
              _outlineBtn(context, L.cancel, state.closeEdit, fixed: true),
              const SizedBox(width: 9),
              _filledBtn(context, L.save, state.commitEdit, fixed: true),
            ],
          ],
        ),
      ],
    );

    if (desktop) {
      return Positioned.fill(
        child: Container(
          color: const Color(0xAA0B0C14),
          child: Center(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 60, offset: Offset(0, 24))]),
              child: content,
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: const Color(0xA80B0C14),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(color: p.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: SafeArea(top: false, child: content),
          ),
        ),
      ),
    );
  }

  Widget _uploadButton(BuildContext context, PlayerAppState state, NocturnePalette p, String label) {
    return OutlinedButton(
      onPressed: state.pickDraftCover,
      style: OutlinedButton.styleFrom(foregroundColor: p.accent, side: BorderSide(color: p.accent), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7)),
      child: Text(label, style: const TextStyle(fontSize: 11.5)),
    );
  }

  Widget _field(BuildContext context, {required String hint, required String value, required ValueChanged<String> onChanged}) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return TextFormField(
      key: ValueKey('$hint-$value'.hashCode),
      initialValue: value,
      onChanged: onChanged,
      style: TextStyle(fontSize: 12.5, color: p.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.muted),
        filled: true,
        fillColor: p.bg,
        contentPadding: const EdgeInsets.all(11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.line)),
      ),
    );
  }

  Widget _outlineBtn(BuildContext context, String label, VoidCallback onTap, {bool fixed = false}) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final btn = OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.line), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18)),
      child: Text(label, style: const TextStyle(fontSize: 12.5)),
    );
    return btn;
  }

  Widget _filledBtn(BuildContext context, String label, VoidCallback onTap, {bool fixed = false}) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: p.accentDim, foregroundColor: p.accent, side: BorderSide(color: p.accent), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18)),
      child: Text(label, style: const TextStyle(fontSize: 12.5)),
    );
  }
}
