import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../state/app_screen.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';
import '../../widgets/toast_overlay.dart';
import '../shared/color_picker_screen.dart';
import '../shared/incoming_pair_dialog.dart';
import '../shared/sync_dialog.dart';
import '../shared/track_edit_sheet.dart';
import 'library_screen.dart';
import 'onboarding_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';
import 'song_screen.dart';
import 'transfer_screen.dart';

/// Root scaffold for the phone build: bottom tab bar + the four main
/// screens, with the full-screen song view, colour-picker, tag editor,
/// sync-prompt and incoming-pair dialogs layered as overlays exactly like
/// the prototype's absolutely-positioned panels.
class PhoneShell extends StatelessWidget {
  const PhoneShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;

    if (state.screen == AppScreen.onboard) {
      return const Scaffold(body: OnboardingScreen());
    }

    Widget body;
    switch (state.screen) {
      case AppScreen.queue:
        body = const QueueScreen();
      case AppScreen.transfer:
        body = const TransferScreen();
      case AppScreen.settings:
        body = const SettingsScreen();
      case AppScreen.library:
      case AppScreen.song:
        body = const LibraryScreen();
      case AppScreen.onboard:
        body = const SizedBox.shrink();
    }

    return PopScope(
      canPop: _canPopToOs(state),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(state);
      },
      child: Scaffold(
        body: ToastOverlay(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: body),
                  _BottomNav(state: state, p: p),
                ],
              ),
              if (state.screen == AppScreen.song) const SongScreen(),
              if (state.colorPickerOpen) const ColorPickerScreen(),
              if (state.editingTrack) const TrackEditSheet(),
              if (state.syncPromptVisible) const SyncDialog(),
              if (state.pendingIncomingPair != null) const IncomingPairDialog(),
            ],
          ),
        ),
      ),
    );
  }

  /// Only let the OS handle back (minimize/close the app) once there's
  /// nothing left in-app to back out of: no dialog/overlay open, not on
  /// the full-screen song view, and already on the library tab.
  bool _canPopToOs(PlayerAppState state) {
    return state.pendingIncomingPair == null &&
        !state.syncPromptVisible &&
        !state.editingTrack &&
        !state.colorPickerOpen &&
        state.screen != AppScreen.song &&
        state.screen == AppScreen.library;
  }

  /// Closes whatever's on top first (dialogs/overlays before the song
  /// screen before tab navigation), mirroring the Stack's paint order in
  /// build() above so back always dismisses the thing the user actually
  /// sees on top.
  void _handleBack(PlayerAppState state) {
    if (state.pendingIncomingPair != null) {
      state.answerIncomingPair(false);
    } else if (state.syncPromptVisible) {
      state.syncAnswer(false);
    } else if (state.editingTrack) {
      state.closeEdit();
    } else if (state.colorPickerOpen) {
      state.closeColorPicker();
    } else if (state.screen == AppScreen.song) {
      state.closeSong();
    } else if (state.screen != AppScreen.library) {
      state.nav(AppScreen.library);
    }
  }
}

class _BottomNav extends StatelessWidget {
  final PlayerAppState state;
  final NocturnePalette p;
  const _BottomNav({required this.state, required this.p});

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppScreen.library, PhosphorIconsRegular.musicNotesSimple, state.L.library),
      (AppScreen.queue, PhosphorIconsRegular.listNumbers, state.L.queue),
      (AppScreen.transfer, PhosphorIconsRegular.wifiHigh, state.L.transfer),
      (AppScreen.settings, PhosphorIconsRegular.slidersHorizontal, state.L.settings),
    ];
    final active = state.screen == AppScreen.song ? AppScreen.library : state.screen;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
        child: Row(
          children: items.map((it) {
            final isActive = it.$1 == active;
            return Expanded(
              child: InkWell(
                onTap: () => state.nav(it.$1),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Column(
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(color: isActive ? p.accent : p.muted),
                        child: Icon(it.$2, size: 19, color: isActive ? p.accent : p.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(it.$3, style: TextStyle(fontSize: 10.5, color: isActive ? p.accent : p.muted)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
