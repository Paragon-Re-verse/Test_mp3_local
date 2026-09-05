import 'dart:io';

/// Estimates an MP3's duration by parsing its first valid frame header.
///
/// VBR files carry a Xing/Info (or VBRI) header in the first frame with an
/// exact frame count, which we use when present; otherwise we fall back to
/// a constant-bitrate estimate from the file size.
class Mp3Duration {
  static const _bitrateTableV1L3 = [
    0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
  ];
  static const _bitrateTableV2L3 = [
    0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
  ];
  static const _sampleRatesV1 = [44100, 48000, 32000, 0];
  static const _sampleRatesV2 = [22050, 24000, 16000, 0];
  static const _sampleRatesV25 = [11025, 12000, 8000, 0];

  static Future<int> estimateSeconds(File file) async {
    try {
      final len = await file.length();
      final raf = await file.open();
      try {
        var pos = 0;
        final head = await raf.read(10);
        if (head.length >= 10 && head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33) {
          final tagSize =
              (head[6] << 21) | (head[7] << 14) | (head[8] << 7) | head[9];
          pos = 10 + tagSize;
        }
        await raf.setPosition(pos);
        final searchWindow = await raf.read(64 * 1024);
        final frame = _findFirstFrame(searchWindow);
        if (frame == null) {
          return _fallbackByBitrateGuess(len - pos);
        }
        final vbrFrames = _readXingFrameCount(searchWindow, frame);
        if (vbrFrames != null && frame.sampleRate > 0) {
          final samplesPerFrame = frame.mpegVersion == 1 ? 1152 : 576;
          return ((vbrFrames * samplesPerFrame) / frame.sampleRate).round();
        }
        if (frame.bitrateBps > 0) {
          final audioBytes = len - pos;
          return ((audioBytes * 8) / frame.bitrateBps).round();
        }
        return _fallbackByBitrateGuess(len - pos);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return 0;
    }
  }

  static int _fallbackByBitrateGuess(int audioBytes) {
    // ~128kbps is a reasonable prior when no frame header is parseable.
    const assumedBps = 128 * 1000;
    if (audioBytes <= 0) return 0;
    return ((audioBytes * 8) / assumedBps).round();
  }

  static _FrameInfo? _findFirstFrame(List<int> b) {
    for (var i = 0; i + 4 < b.length; i++) {
      if (b[i] != 0xFF || (b[i + 1] & 0xE0) != 0xE0) continue;
      final versionBits = (b[i + 1] >> 3) & 0x3;
      final layerBits = (b[i + 1] >> 1) & 0x3;
      if (versionBits == 1 || layerBits == 0) continue; // reserved
      final mpegVersion = versionBits == 3 ? 1 : (versionBits == 2 ? 2 : 25);
      final layer = 4 - layerBits; // 1,2,3
      if (layer != 3) continue; // we only care about Layer III (mp3)
      final bitrateIdx = (b[i + 2] >> 4) & 0xF;
      final sampleIdx = (b[i + 2] >> 2) & 0x3;
      if (bitrateIdx == 0 || bitrateIdx == 15 || sampleIdx == 3) continue;
      final padding = (b[i + 2] >> 1) & 0x1;
      final bitrateKbps = mpegVersion == 1
          ? _bitrateTableV1L3[bitrateIdx]
          : _bitrateTableV2L3[bitrateIdx];
      final sampleRate = mpegVersion == 1
          ? _sampleRatesV1[sampleIdx]
          : mpegVersion == 2
              ? _sampleRatesV2[sampleIdx]
              : _sampleRatesV25[sampleIdx];
      if (bitrateKbps == 0 || sampleRate == 0) continue;
      final samplesPerFrame = mpegVersion == 1 ? 1152 : 576;
      final frameLen =
          (samplesPerFrame ~/ 8 * bitrateKbps * 1000) ~/ sampleRate + padding;
      if (frameLen <= 0) continue;
      return _FrameInfo(
        offset: i,
        mpegVersion: mpegVersion,
        sampleRate: sampleRate,
        bitrateBps: bitrateKbps * 1000,
        frameLength: frameLen,
      );
    }
    return null;
  }

  /// Looks for a "Xing"/"Info" (MPEG audio) or "VBRI" header just after the
  /// first frame's own header, and returns the total frame count if found.
  static int? _readXingFrameCount(List<int> b, _FrameInfo frame) {
    // Xing/Info sits after the side-info, whose size depends on version and
    // channel mode - we scan a small window for the tag rather than compute
    // the exact offset.
    final start = frame.offset + 4;
    final end = (frame.offset + frame.frameLength).clamp(0, b.length);
    for (var i = start; i + 4 <= end && i + 4 <= b.length; i++) {
      final tag = String.fromCharCodes(b.sublist(i, i + 4));
      if (tag == 'Xing' || tag == 'Info') {
        var p = i + 4;
        if (p + 8 > b.length) return null;
        final flags = (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
        p += 4;
        if (flags & 0x1 != 0 && p + 4 <= b.length) {
          return (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
        }
        return null;
      }
      if (tag == 'VBRI') {
        var p = i + 4 + 2 + 4 + 2; // tag+version+delay+quality
        if (p + 4 <= b.length) {
          return (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
        }
        return null;
      }
    }
    return null;
  }
}

class _FrameInfo {
  final int offset;
  final int mpegVersion;
  final int sampleRate;
  final int bitrateBps;
  final int frameLength;
  _FrameInfo({
    required this.offset,
    required this.mpegVersion,
    required this.sampleRate,
    required this.bitrateBps,
    required this.frameLength,
  });
}
