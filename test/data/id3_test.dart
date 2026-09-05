import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne_player/data/id3.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('id3_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('write then read round-trips title/artist/album', () async {
    final file = File('${tmp.path}/track.mp3');
    // Fake "audio" payload the writer must preserve untouched.
    final audio = Uint8List.fromList(List.generate(256, (i) => i % 256));
    await file.writeAsBytes(audio);

    await Id3Writer.write(file, title: 'Ночной трамвай', artist: 'Кассетный сад', album: 'Полустанок');

    final tags = await Id3Reader.read(file);
    expect(tags, isNotNull);
    expect(tags!.title, 'Ночной трамвай');
    expect(tags.artist, 'Кассетный сад');
    expect(tags.album, 'Полустанок');

    // The original audio bytes must still be present, verbatim, after the tag.
    final bytes = await file.readAsBytes();
    final tail = bytes.sublist(bytes.length - audio.length);
    expect(tail, equals(audio));
  });

  test('write then read round-trips an embedded cover image', () async {
    final file = File('${tmp.path}/track2.mp3');
    await file.writeAsBytes(Uint8List.fromList(List.filled(64, 7)));
    final cover = Uint8List.fromList(List.generate(300, (i) => (i * 3) % 256));

    await Id3Writer.write(file, title: 'T', artist: 'A', album: 'B', coverBytes: cover, coverMime: 'image/png');

    final tags = await Id3Reader.read(file);
    expect(tags!.coverBytes, equals(cover));
    expect(tags.coverMime, 'image/png');
  });

  test('rewriting tags replaces the previous tag instead of stacking', () async {
    final file = File('${tmp.path}/track3.mp3');
    await file.writeAsBytes(Uint8List.fromList(List.filled(32, 1)));

    await Id3Writer.write(file, title: 'First', artist: 'A', album: 'B');
    await Id3Writer.write(file, title: 'Second', artist: 'A', album: 'B');

    final tags = await Id3Reader.read(file);
    expect(tags!.title, 'Second');
  });

  test('a file with no ID3v2 header reads as null', () async {
    final file = File('${tmp.path}/notags.mp3');
    await file.writeAsBytes(Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, 1, 2, 3]));
    final tags = await Id3Reader.read(file);
    expect(tags, isNull);
  });
}
