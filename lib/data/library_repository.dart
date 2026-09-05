import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/track.dart';
import 'app_store.dart';
import 'id3.dart';
import 'mp3_duration.dart';

class LibraryRepository {
  final AppStore store;
  LibraryRepository(this.store);

  static const _hues = [268, 212, 30, 158, 340, 190];

  /// Recursively scans [folder] for .mp3 files, reads their ID3 tags and an
  /// estimated duration, and merges in the app's own per-track tag labels
  /// (which aren't part of ID3 - they're app-level filter labels).
  Future<List<Track>> scan(String folder) async {
    final dir = Directory(folder);
    if (!await dir.exists()) return [];

    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.mp3') {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    final trackTags = await store.trackTags;
    final coverOverrides = await store.trackCoverOverrides;

    final tracks = <Track>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      Id3Tags? tags;
      try {
        tags = await Id3Reader.read(f);
      } catch (_) {
        tags = null;
      }
      final duration = await Mp3Duration.estimateSeconds(f);
      final fallbackTitle = p.basenameWithoutExtension(f.path);
      tracks.add(Track(
        id: f.path,
        filePath: f.path,
        title: (tags?.title.isNotEmpty ?? false) ? tags!.title : fallbackTitle,
        artist: (tags?.artist.isNotEmpty ?? false) ? tags!.artist : '',
        album: (tags?.album.isNotEmpty ?? false) ? tags!.album : '',
        year: tags?.year,
        durationSeconds: duration,
        coverHue: _hues[i % _hues.length],
        tags: trackTags[f.path] ?? const [],
        customCoverPath: coverOverrides[f.path],
      ));
    }
    return tracks;
  }

  Future<void> saveTrackTags(String trackId, List<String> tags) async {
    final map = await store.trackTags;
    map[trackId] = tags;
    await store.setTrackTags(map);
  }

  Future<void> saveTrackMetadata(
    Track track, {
    required String title,
    required String artist,
    required String album,
    String? newCoverPath,
  }) async {
    await Id3Writer.write(
      File(track.filePath),
      title: title,
      artist: artist,
      album: album,
      coverBytes: newCoverPath != null ? await File(newCoverPath).readAsBytes() : null,
      coverMime: newCoverPath != null ? _mimeFor(newCoverPath) : null,
    );
    if (newCoverPath != null) {
      final map = await store.trackCoverOverrides;
      map[track.id] = newCoverPath;
      await store.setTrackCoverOverrides(map);
    }
  }

  String _mimeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.png') return 'image/png';
    return 'image/jpeg';
  }
}
