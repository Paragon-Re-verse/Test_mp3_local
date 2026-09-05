import 'package:media_kit/media_kit.dart';

import 'playback_engine.dart';

/// Real playback backend, used by the shipping app on Android and Windows.
/// Call [MediaKit.ensureInitialized] once before constructing this.
class MediaKitPlaybackEngine implements PlaybackEngine {
  final Player _player = Player();

  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Stream<Duration> get duration => _player.stream.duration;
  @override
  Stream<bool> get playing => _player.stream.playing;
  @override
  Stream<bool> get completed => _player.stream.completed;
  @override
  bool get isPlaying => _player.state.playing;

  @override
  Future<void> open(String uri, {bool play = true}) => _player.open(Media(uri), play: play);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  void dispose() => _player.dispose();
}
