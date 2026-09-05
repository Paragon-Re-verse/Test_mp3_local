import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nocturne_player/screens/desktop/desktop_shell.dart';
import 'package:nocturne_player/state/app_screen.dart';
import 'package:nocturne_player/state/player_app_state.dart';
import 'package:nocturne_player/theme/nocturne_theme.dart';

import 'test_state.dart';

/// Renders [DesktopShell] at the prototype's Windows viewport (1180x720).
void main() {
  testWidgets('desktop now-playing layout', (tester) async {
    tester.view.physicalSize = const Size(1180, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await buildTestState(isDesktop: true);
    state.screen = AppScreen.library;
    state.queueIds = ['1', '4', '6', '2'];
    state.curIndex = 0;
    state.playing = true;
    state.position = const Duration(seconds: 82);

    final palette = NocturnePalette.of(dark: true, color: AccentChoice.system);
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerAppState>.value(
        value: state,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildNocturneTheme(palette), home: const DesktopShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(find.byType(DesktopShell), matchesGoldenFile('goldens/desktop_now_playing.png'));
  });

  testWidgets('desktop output switched to phone', (tester) async {
    tester.view.physicalSize = const Size(1180, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await buildTestState(isDesktop: true);
    state.screen = AppScreen.library;
    state.queueIds = ['1', '4', '6'];
    state.curIndex = 0;
    state.playing = true;
    state.output = AudioOutput.peer;

    final palette = NocturnePalette.of(dark: true, color: AccentChoice.system);
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerAppState>.value(
        value: state,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildNocturneTheme(palette), home: const DesktopShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(find.byType(DesktopShell), matchesGoldenFile('goldens/desktop_output_phone.png'));
  });
}
