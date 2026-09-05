import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nocturne_player/screens/phone/phone_shell.dart';
import 'package:nocturne_player/state/app_screen.dart';
import 'package:nocturne_player/state/player_app_state.dart';
import 'package:nocturne_player/theme/nocturne_theme.dart';

import 'test_state.dart';

/// Renders [PhoneShell] at the prototype's own phone viewport (400x860,
/// see the dc.html intro tags) so these goldens can be visually compared
/// against the design screen-by-screen.
Future<void> _pumpPhone(WidgetTester tester, PlayerAppState state) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final palette = NocturnePalette.of(dark: true, color: AccentChoice.system);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildNocturneTheme(palette), home: const PhoneShell()),
    ),
  );
  // Not pumpAndSettle: the queue/transfer screens have infinitely-repeating
  // animations (equalizer bars, radar rings) that would never "settle".
  // A couple of fixed pumps is enough for entrance transitions to finish.
  await tester.pump();
  // Long enough for the transfer screen's two staggered 1s-delayed radar
  // rings to actually start, so no Timer is left pending at test teardown.
  await tester.pump(const Duration(milliseconds: 1200));
}

void main() {
  testWidgets('onboarding screen', (tester) async {
    final state = await buildTestState();
    state.folder = null;
    state.screen = AppScreen.onboard;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_onboarding.png'));
  });

  testWidgets('library screen', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.library;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_library.png'));
  });

  testWidgets('library screen with filter panel open', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.library;
    state.filterOpen = true;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_library_filter.png'));
  });

  testWidgets('queue screen', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.queue;
    state.queueIds = ['1', '4', '6'];
    state.curIndex = 0;
    state.playing = true;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_queue.png'));
  });

  testWidgets('transfer screen scanning', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.transfer;
    state.scanningDevices = true;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_transfer.png'));
  });

  testWidgets('settings screen', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.settings;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_settings.png'));
  });

  testWidgets('settings screen with custom colour picker open', (tester) async {
    final state = await buildTestState();
    state.screen = AppScreen.settings;
    state.colorChoice = AccentChoice.custom;
    state.colorPickerOpen = true;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_color_picker.png'));
  });

  testWidgets('song screen', (tester) async {
    final state = await buildTestState();
    state.queueIds = ['1', '4', '6'];
    state.curIndex = 0;
    state.playing = true;
    state.position = const Duration(seconds: 82);
    state.screen = AppScreen.song;
    await _pumpPhone(tester, state);
    await expectLater(find.byType(PhoneShell), matchesGoldenFile('goldens/phone_song.png'));
  });
}
