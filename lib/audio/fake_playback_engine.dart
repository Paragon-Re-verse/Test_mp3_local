import 'dart:async';

import 'playback_engine.dart';

/// No-op playback backend for widget/golden tests: tracks state and fires
/// the same stream shapes the real engine would, without touching any
/// audio hardware or native library.
class FakePlaybackEngine implements PlaybackEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();

  bool _isPlaying = false;

  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> open(String uri, {bool play = true}) async {
    _duration.add(const Duration(minutes: 3));
    _position.add(Duration.zero);
    _isPlaying = play;
    _playing.add(play);
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _position.add(position);
  }

  @override
  void dispose() {
    _position.close();
    _duration.close();
    _playing.close();
    _completed.close();
  }
}
