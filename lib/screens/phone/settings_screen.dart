import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    Widget sectionLabel(String s) =>
        Text(s.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, color: p.accent, fontFamily: kMonoFamily, fontWeight: FontWeight.w500));

    return Container(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Text(L.settings, style: TextStyle(fontSize: 24, color: p.text, letterSpacing: -0.2)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  sectionLabel(L.general),
                  const SizedBox(height: 14),
                  Text(L.theme, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  const SizedBox(height: 8),
                  Row(
                    children: AppThemeMode.values.map((m) {
                      final active = state.themeMode == m;
                      final label = switch (m) { AppThemeMode.system => L.system, AppThemeMode.light => L.lightT, AppThemeMode.dark => L.darkT };
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SegButton(label: label, active: active, onTap: () => state.setThemeMode(m)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(L.color, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        _ColorRow(choice: AccentChoice.system, label: L.cSystem, swatch: const Color(0xFF9184D9)),
                        _ColorRow(choice: AccentChoice.amber, label: L.cAmber, swatch: NocturnePalette.amber),
                        _ColorRow(choice: AccentChoice.ubuntu, label: L.cUbuntu, swatch: NocturnePalette.ubuntu),
                        _ColorRow(choice: AccentChoice.custom, label: L.cCustom, swatch: colorFromHex(state.customHex), isLast: true),
                      ],
                    ),
                  ),
                  if (state.colorChoice == AccentChoice.custom)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: state.openColorPicker,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(border: Border.all(color: p.accent), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(width: 26, height: 26, decoration: BoxDecoration(color: colorFromHex(state.customHex), borderRadius: BorderRadius.circular(6))),
                              const SizedBox(width: 10),
                              Expanded(child: Text(state.customHex, style: TextStyle(fontSize: 12.5, color: p.text, fontFamily: kMonoFamily))),
                              Icon(PhosphorIconsRegular.caretRight, size: 14, color: p.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(L.language, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _SegButton(label: 'Русский', active: state.lang == AppLang.ru, onTap: () => state.setLang(AppLang.ru))),
                      const SizedBox(width: 6),
                      Expanded(child: _SegButton(label: 'English', active: state.lang == AppLang.en, onTap: () => state.setLang(AppLang.en))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => state.setTranscode(!state.transcode),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(L.transcode, style: TextStyle(fontSize: 12.5, color: p.text)),
                                const SizedBox(height: 3),
                                Text(L.transcodeHint, style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.4)),
                              ],
                            ),
                          ),
                          _Switch(on: state.transcode, p: p),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  sectionLabel(L.network),
                  const SizedBox(height: 12),
                  Text(L.deviceName, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: ValueKey('devname-${state.deviceName}'),
                    initialValue: state.deviceName,
                    onFieldSubmitted: state.setDeviceName,
                    onEditingComplete: () {},
                    style: TextStyle(fontSize: 12.5, color: p.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: p.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.line)),
                      contentPadding: const EdgeInsets.all(11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(context, PhosphorIconsRegular.arrowsClockwise, L.restart, state.restartNetwork),
                  const SizedBox(height: 8),
                  _row(context, PhosphorIconsRegular.power, state.netOn ? L.disable : L.enable, state.toggleNet),
                  const SizedBox(height: 22),
                  sectionLabel(L.libSec),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsRegular.folder, size: 16, color: p.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L.folder, style: TextStyle(fontSize: 12.5, color: p.text)),
                              const SizedBox(height: 3),
                              Text(state.folder ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: state.pickFolder,
                          style: OutlinedButton.styleFrom(foregroundColor: p.accent, side: BorderSide(color: p.accent), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7)),
                          child: Text(L.change, style: const TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  sectionLabel(L.tagsSec),
                  const SizedBox(height: 8),
                  Text(L.tagsHint, style: TextStyle(fontSize: 11, color: p.muted, height: 1.5)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        ...state.allTags.map((t) => _TagRow(name: t)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: ValueKey('newtag-${state.newTagDraft.length}'),
                                  onChanged: state.setNewTagDraft,
                                  onSubmitted: (_) => state.addTag(),
                                  style: TextStyle(fontSize: 12.5, color: p.text),
                                  decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: L.newTag, hintStyle: TextStyle(color: p.muted)),
                                ),
                              ),
                              TextButton(
                                onPressed: state.addTag,
                                style: TextButton.styleFrom(foregroundColor: p.accent),
                                child: Text(L.add, style: const TextStyle(fontSize: 11.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: p.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: p.text))),
          ],
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.accentDim : Colors.transparent,
          border: Border.all(color: active ? p.accent : p.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? p.accent : p.text)),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final AccentChoice choice;
  final String label;
  final Color swatch;
  final bool isLast;
  const _ColorRow({required this.choice, required this.label, required this.swatch, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final active = state.colorChoice == choice;
    return InkWell(
      onTap: () => choice == AccentChoice.custom ? state.openColorPicker() : state.setColorChoice(choice),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: p.line))),
        child: Row(
          children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: swatch, shape: BoxShape.circle)),
            const SizedBox(width: 11),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: active ? p.text : p.muted))),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? p.accent : p.line)),
              child: active ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle))) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool on;
  final NocturnePalette p;
  const _Switch({required this.on, required this.p});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38,
      height: 22,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? p.accent : Colors.transparent,
        border: on ? null : Border.all(color: p.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Container(width: 18, height: 18, decoration: BoxDecoration(color: on ? p.bg : p.line, shape: BoxShape.circle)),
    );
  }
}

class _TagRow extends StatelessWidget {
  final String name;
  const _TagRow({required this.name});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final count = state.tracks.where((t) => t.tags.contains(name)).length;
    final renaming = state.renamingTag == name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: renaming
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    controller: TextEditingController(text: state.renameValue)..selection = TextSelection.collapsed(offset: state.renameValue.length),
                    onChanged: state.setRenameValue,
                    onSubmitted: (_) => state.commitRenameTag(),
                    style: TextStyle(fontSize: 12, color: p.text),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: p.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: p.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: state.commitRenameTag,
                  style: TextButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.bg),
                  child: Text(Strings.forLang(state.lang).save, style: const TextStyle(fontSize: 11.5)),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(name, style: TextStyle(fontSize: 12.5, color: p.text))),
                Text('$count', style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                const SizedBox(width: 8),
                InkWell(onTap: () => state.startRenameTag(name), child: Icon(PhosphorIconsRegular.pencilSimple, size: 13, color: p.muted)),
                const SizedBox(width: 10),
                InkWell(onTap: () => state.deleteTag(name), child: Icon(PhosphorIconsRegular.trash, size: 13, color: p.muted)),
              ],
            ),
    );
  }
}
