import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../phone/settings_screen.dart' show SegButton, ColorRow, SettingsSwitch, TagRow, NewTagField;
import 'desktop_shell.dart' show OutputSwitch;

/// Desktop counterpart of the phone Settings screen: same state, same
/// underlying widgets (General/Network/Library/Tags reuse the exact
/// SegButton/ColorRow/SettingsSwitch/TagRow/NewTagField widgets from
/// settings_screen.dart), laid out as the two-column grid from the PC
/// prototype instead of one scrolling list, plus a PC-only Output section
/// (the same segmented PC/Phone switch already on the now-playing pane,
/// surfaced here too since a settings page is where a user expects to find
/// "what does this window play out of" - defaults to PC speakers).
class DesktopSettingsScreen extends StatelessWidget {
  const DesktopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;

    Widget sectionLabel(String s) =>
        Text(s.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, color: p.accent, fontFamily: kMonoFamily, fontWeight: FontWeight.w500));

    return Container(
      color: p.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
            child: Text(L.settings, style: TextStyle(fontSize: 22, color: p.text)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel(L.general),
                        const SizedBox(height: 14),
                        Text(L.theme, style: TextStyle(fontSize: 12, color: p.muted)),
                        const SizedBox(height: 8),
                        Row(
                          children: AppThemeMode.values.map((m) {
                            final active = state.themeMode == m;
                            final label = switch (m) { AppThemeMode.system => L.system, AppThemeMode.light => L.lightT, AppThemeMode.dark => L.darkT };
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: SegButton(label: label, active: active, onTap: () => state.setThemeMode(m)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(L.color, style: TextStyle(fontSize: 12, color: p.muted)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              ColorRow(choice: AccentChoice.system, label: L.cSystem, swatch: const Color(0xFF9184D9)),
                              ColorRow(choice: AccentChoice.amber, label: L.cAmber, swatch: NocturnePalette.amber),
                              ColorRow(choice: AccentChoice.ubuntu, label: L.cUbuntu, swatch: NocturnePalette.ubuntu),
                              ColorRow(choice: AccentChoice.custom, label: L.cCustom, swatch: colorFromHex(state.customHex), isLast: true),
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
                                    Container(width: 24, height: 24, decoration: BoxDecoration(color: colorFromHex(state.customHex), borderRadius: BorderRadius.circular(6))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(state.customHex, style: TextStyle(fontSize: 12, color: p.text, fontFamily: kMonoFamily))),
                                    Icon(PhosphorIconsRegular.caretRight, size: 13, color: p.muted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(L.language, style: TextStyle(fontSize: 12, color: p.muted)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: SegButton(label: 'Русский', active: state.lang == AppLang.ru, onTap: () => state.setLang(AppLang.ru))),
                            const SizedBox(width: 6),
                            Expanded(child: SegButton(label: 'English', active: state.lang == AppLang.en, onTap: () => state.setLang(AppLang.en))),
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
                                SettingsSwitch(on: state.transcode, p: p),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        sectionLabel(L.output),
                        const SizedBox(height: 12),
                        const OutputSwitch(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel(L.network),
                        const SizedBox(height: 14),
                        Text(L.deviceName, style: TextStyle(fontSize: 12, color: p.muted)),
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
                        Row(
                          children: [
                            Expanded(child: _actionRow(context, PhosphorIconsRegular.arrowsClockwise, L.restart, state.restartNetwork)),
                            const SizedBox(width: 8),
                            Expanded(child: _actionRow(context, PhosphorIconsRegular.power, state.netOn ? L.disable : L.enable, state.toggleNet)),
                          ],
                        ),
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
                              ...state.allTags.map((t) => TagRow(name: t)),
                              const NewTagField(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final p = Theme.of(context).extension<NocturnePalette>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 15, color: p.muted),
            const SizedBox(width: 9),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: p.text))),
          ],
        ),
      ),
    );
  }
}
