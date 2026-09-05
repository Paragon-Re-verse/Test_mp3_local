import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne_player/data/mp3_duration.dart';

/// Builds a minimal MPEG1 Layer III frame header (128kbps, 44.1kHz, no
/// padding) followed by a Xing VBR header reporting an exact frame count,
/// so [Mp3Duration] can be exercised without a real encoded mp3 file.
Uint8List _buildFakeMp3WithXingFrames(int frameCount) {
  final header = <int>[0xFF, 0xFB, 0x90, 0x00];
  final xing = <int>[
    ...('Xing'.codeUnits),
    0, 0, 0, 1, // flags: frames field present
    (frameCount >> 24) & 0xFF, (frameCount >> 16) & 0xFF, (frameCount >> 8) & 0xFF, frameCount & 0xFF,
  ];
  final padding = List<int>.filled(64, 0);
  return Uint8List.fromList([...header, ...xing, ...padding]);
}

Uint8List _buildFakeMp3Cbr({required int audioBytes}) {
  final header = <int>[0xFF, 0xFB, 0x90, 0x00];
  return Uint8List.fromList([...header, ...List<int>.filled(audioBytes, 0)]);
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mp3dur_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('reads exact duration from a Xing VBR header', () async {
    final file = File('${tmp.path}/vbr.mp3');
    // 1000 frames * 1152 samples/frame / 44100 Hz = 26.122s -> rounds to 26.
    await file.writeAsBytes(_buildFakeMp3WithXingFrames(1000));

    final seconds = await Mp3Duration.estimateSeconds(file);
    expect(seconds, 26);
  });

  test('falls back to a bitrate estimate for CBR files without Xing', () async {
    final file = File('${tmp.path}/cbr.mp3');
    // 128kbps -> 16000 bytes/sec; 160000 bytes of audio ~= 10s.
    await file.writeAsBytes(_buildFakeMp3Cbr(audioBytes: 160000));

    final seconds = await Mp3Duration.estimateSeconds(file);
    expect(seconds, closeTo(10, 1));
  });

  test('returns 0 for an unparseable file instead of throwing', () async {
    final file = File('${tmp.path}/junk.mp3');
    await file.writeAsBytes(Uint8List.fromList(List.filled(20, 0)));
    final seconds = await Mp3Duration.estimateSeconds(file);
    expect(seconds, 0);
  });
}
