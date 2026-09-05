/// One scanned MP3 file. `id` is the absolute file path, which is stable
/// across app restarts (unlike a random UUID) and lets us key custom tags
/// and cover overrides by file without a separate database.
class Track {
  final String id;
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final int? year;
  final List<String> tags;
  final String? customCoverPath;
  final int coverHue;

  const Track({
    required this.id,
    required this.filePath,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.coverHue,
    this.year,
    this.tags = const [],
    this.customCoverPath,
  });

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    List<String>? tags,
    String? customCoverPath,
  }) {
    return Track(
      id: id,
      filePath: filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds,
      year: year,
      coverHue: coverHue,
      tags: tags ?? this.tags,
      customCoverPath: customCoverPath ?? this.customCoverPath,
    );
  }

  static String formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
