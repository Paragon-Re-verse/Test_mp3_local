import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  final value = int.parse(clean, radix: 16);
  return Color(0xFF000000 | value);
}

/// Accent-color choices from Settings → Colour.
enum AccentChoice { system, amber, ubuntu, custom }

enum AppThemeMode { system, light, dark }

/// Ports the Nocturne design-system tokens (see
/// project/_ds/nocturne-.../styles.css) plus the app-level `[data-app]`
/// variable overrides from the prototype (MP3 Local Player.dc.html) into a
/// single Dart object so every screen reads the same palette the prototype
/// did.
class NocturnePalette extends ThemeExtension<NocturnePalette> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentDim; // --accd : accent-tinted container background
  final Color onAccent;
  final Brightness brightness;

  const NocturnePalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentDim,
    required this.onAccent,
    required this.brightness,
  });

  @override
  NocturnePalette copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accentDim,
    Color? onAccent,
    Brightness? brightness,
  }) {
    return NocturnePalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      onAccent: onAccent ?? this.onAccent,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  NocturnePalette lerp(ThemeExtension<NocturnePalette>? other, double t) {
    if (other is! NocturnePalette) return this;
    return NocturnePalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }

  static const _neutral900 = Color(0xFF292B31);
  static const _neutral800 = Color(0xFF3F424D);
  static const _neutral500 = Color(0xFF9397AB);
  static const _neutral300 = Color(0xFFCFD3E5);
  static const _neutral200 = Color(0xFFE4E7F5);
  static const _neutral100 = Color(0xFFF3F5FE);
  static const _neutral600 = Color(0xFF75798C);

  static const systemAccentDark = Color(0xFF9184D9);
  static const accent800 = Color(0xFF423A6A);
  static const accent200 = Color(0xFFE7E5FE);
  static const accent100 = Color(0xFFF5F4FF);

  static const amber = Color(0xFFF0A13A);
  static const amberAccdDark = Color(0xFF4A3517);
  static const amberAccdLight = Color(0xFFFBE9CF);

  static const ubuntu = Color(0xFFE95420);
  static const ubuntuAccdDark = Color(0xFF4A2314);
  static const ubuntuAccdLight = Color(0xFFFBDCD0);

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  factory NocturnePalette.of({
    required bool dark,
    required AccentChoice color,
    Color? customHex,
  }) {
    final bg = dark ? const Color(0xFF161826) : _neutral100;
    final surface = dark ? const Color(0xFF232532) : _neutral200;
    final surface2 = dark ? _neutral900 : _neutral200;
    final line = dark ? _neutral800 : _neutral300;
    final text = dark ? const Color(0xFFE9E9ED) : _neutral900;
    final muted = dark ? _neutral500 : _neutral600;
    final onAccent = dark ? accent100 : _neutral100;

    late Color accent;
    late Color accentDim;
    switch (color) {
      case AccentChoice.amber:
        accent = amber;
        accentDim = dark ? amberAccdDark : amberAccdLight;
      case AccentChoice.ubuntu:
        accent = ubuntu;
        accentDim = dark ? ubuntuAccdDark : ubuntuAccdLight;
      case AccentChoice.custom:
        accent = customHex ?? systemAccentDark;
        accentDim = _mix(accent, surface, 0.22);
      case AccentChoice.system:
        accent = systemAccentDark;
        accentDim = dark ? accent800 : accent200;
    }

    return NocturnePalette(
      bg: bg,
      surface: surface,
      surface2: surface2,
      line: line,
      text: text,
      muted: muted,
      accent: accent,
      accentDim: accentDim,
      onAccent: onAccent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
  }
}

const kFontFamily = 'Inter';
const kMonoFamily = 'RobotoMono';

ThemeData buildNocturneTheme(NocturnePalette p) {
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    scaffoldBackgroundColor: p.bg,
    fontFamily: kFontFamily,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: const Color(0xFFE0605A),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
    ),
    dividerColor: p.line,
    extensions: [p],
  );
}

extension NocturnePaletteExt on NocturnePalette {
  static NocturnePalette of(BuildContext context) =>
      Theme.of(context).extension<NocturnePalette>()!;
}
