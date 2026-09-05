import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'audio/media_kit_playback_engine.dart';
import 'data/app_store.dart';
import 'data/library_repository.dart';
import 'network/network_service.dart';
import 'screens/app_root.dart';
import 'state/player_app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final store = await AppStore.load();
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  final library = LibraryRepository(store);

  late PlayerAppState state;
  final network = NetworkService(
    store: store,
    isDesktop: isDesktop,
    resolveTrackPath: (id) => state.trackById(id)?.filePath ?? '',
  );
  state = PlayerAppState(
    store: store,
    library: library,
    network: network,
    isDesktop: isDesktop,
    engine: MediaKitPlaybackEngine(),
  );

  runApp(NocturneBootstrap(state: state));
}

/// Shows a minimal splash while [PlayerAppState.init] loads settings, scans
/// the library folder (if one was already chosen) and stands up the local
/// network services, then hands off to [AppRoot].
class NocturneBootstrap extends StatefulWidget {
  final PlayerAppState state;
  const NocturneBootstrap({super.key, required this.state});

  @override
  State<NocturneBootstrap> createState() => _NocturneBootstrapState();
}

class _NocturneBootstrapState extends State<NocturneBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.state.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF161826),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF9184D9))),
        ),
      );
    }
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: const AppRoot(),
    );
  }
}
