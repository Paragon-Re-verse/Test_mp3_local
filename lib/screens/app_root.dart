import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/player_app_state.dart';
import '../theme/nocturne_theme.dart';
import 'desktop/desktop_shell.dart';
import 'phone/phone_shell.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final systemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = state.themeMode == AppThemeMode.dark ||
        (state.themeMode == AppThemeMode.system && systemDark);
    final custom = _tryParseColor(state.customHex);
    final palette = NocturnePalette.of(dark: dark, color: state.colorChoice, customHex: custom);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nocturne',
      theme: buildNocturneTheme(palette),
      home: state.isDesktop ? const DesktopShell() : const PhoneShell(),
    );
  }

  Color? _tryParseColor(String hex) {
    try {
      return colorFromHex(hex);
    } catch (_) {
      return null;
    }
  }
}
