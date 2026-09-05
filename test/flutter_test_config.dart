import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter test` runs with no fonts loaded by default, so without this,
/// every golden screenshot renders Cyrillic text and Phosphor icons as
/// empty tofu boxes. Loading every font declared in FontManifest.json
/// (our bundled Inter/RobotoMono plus phosphor_flutter's icon font) makes
/// goldens actually show what the app renders.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (string) async => json.decode(string) as List<dynamic>,
  );
  for (final dynamic entry in manifest) {
    final font = entry as Map<String, dynamic>;
    final family = font['family'] as String;
    final assets = (font['fonts'] as List<dynamic>).cast<Map<String, dynamic>>();
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}
