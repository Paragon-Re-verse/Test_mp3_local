/// Working copy of a track's editable fields while the tag-editor sheet /
/// dialog is open (phone bottom sheet, PC modal - see openEdit in the
/// prototype's script).
class TrackDraft {
  final String trackId;
  String title;
  String artist;
  String album;
  List<String> tags;
  String? newCoverPath;

  TrackDraft({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.tags,
    this.newCoverPath,
  });

  TrackDraft copy() => TrackDraft(
        trackId: trackId,
        title: title,
        artist: artist,
        album: album,
        tags: List.of(tags),
        newCoverPath: newCoverPath,
      );
}
