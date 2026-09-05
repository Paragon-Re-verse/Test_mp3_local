/// Thin seam between [PlayerAppState] and the actual audio backend, so
/// widget/golden tests can run against a fake engine instead of pulling in
/// media_kit's native player (which needs libmpv wired up by the platform
/// runner and isn't available under `flutter test`'s headless harness).
abstract class PlaybackEngine {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get completed;
  bool get isPlaying;

  Future<void> open(String uri, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  void dispose();
}
