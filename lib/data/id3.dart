import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal, dependency-free ID3v2.3/2.4 reader + writer.
///
/// We only need a handful of frames (TIT2/TPE1/TALB/TYER|TDRC/APIC), and we
/// only ever rewrite the whole tag rather than patch frames in place, so a
/// focused reader/writer is simpler and more auditable than pulling in a
/// general-purpose tagging library.
class Id3Tags {
  final String title;
  final String artist;
  final String album;
  final int? year;
  final Uint8List? coverBytes;
  final String? coverMime;

  const Id3Tags({
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    this.coverBytes,
    this.coverMime,
  });
}

class _Frame {
  final String id;
  final Uint8List data;
  _Frame(this.id, this.data);
}

class Id3Reader {
  /// Reads ID3v2 tags from [file]. Returns null if the file has no ID3v2
  /// header (still a valid mp3 - callers should fall back to filename).
  static Future<Id3Tags?> read(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(10);
      if (header.length < 10 ||
          header[0] != 0x49 || // 'I'
          header[1] != 0x44 || // 'D'
          header[2] != 0x33) {
        // 'D3'
        return null;
      }
      final majorVersion = header[3];
      final tagSize = _synchsafe(header.sublist(6, 10));
      await raf.setPosition(10);
      final body = await raf.read(tagSize);
      final frames = _parseFrames(body, majorVersion);

      String textOf(List<String> ids) {
        for (final id in ids) {
          final f = frames[id];
          if (f != null) {
            final t = _decodeText(f.data);
            if (t.isNotEmpty) return t;
          }
        }
        return '';
      }

      int? yearOf() {
        final t = textOf(['TYER', 'TDRC', 'TYE']);
        if (t.isEmpty) return null;
        final m = RegExp(r'\d{4}').firstMatch(t);
        return m == null ? null : int.tryParse(m.group(0)!);
      }

      Uint8List? cover;
      String? coverMime;
      final apic = frames['APIC'] ?? frames['PIC'];
      if (apic != null) {
        final parsed = _parseApic(apic.data);
        cover = parsed?.$1;
        coverMime = parsed?.$2;
      }

      return Id3Tags(
        title: textOf(['TIT2', 'TT2']),
        artist: textOf(['TPE1', 'TP1']),
        album: textOf(['TALB', 'TAL']),
        year: yearOf(),
        coverBytes: cover,
        coverMime: coverMime,
      );
    } finally {
      await raf.close();
    }
  }

  static int _synchsafe(List<int> b) {
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3];
  }

  static Map<String, _Frame> _parseFrames(Uint8List body, int majorVersion) {
    final frames = <String, _Frame>{};
    var pos = 0;
    while (pos + 10 <= body.length) {
      final id = ascii.decode(body.sublist(pos, pos + 4), allowInvalid: true);
      if (id.trim().isEmpty || id.codeUnitAt(0) == 0) break;
      final sizeBytes = body.sublist(pos + 4, pos + 8);
      final size = majorVersion >= 4
          ? _synchsafe(sizeBytes)
          : (sizeBytes[0] << 24) | (sizeBytes[1] << 16) | (sizeBytes[2] << 8) | sizeBytes[3];
      final dataStart = pos + 10;
      if (size < 0 || dataStart + size > body.length) break;
      frames[id] = _Frame(id, body.sublist(dataStart, dataStart + size));
      pos = dataStart + size;
    }
    return frames;
  }

  static String _decodeText(Uint8List data) {
    if (data.isEmpty) return '';
    final encByte = data[0];
    final rest = data.sublist(1);
    String s;
    switch (encByte) {
      case 1: // UTF-16 with BOM
        s = _decodeUtf16(rest);
      case 2: // UTF-16BE no BOM
        s = _decodeUtf16(rest, forceBE: true);
      case 3: // UTF-8
        s = utf8.decode(rest, allowMalformed: true);
      default: // ISO-8859-1
        s = latin1.decode(rest, allowInvalid: true);
    }
    // Strip null terminators / trailing junk.
    final z = s.indexOf('\u0000');
    return (z >= 0 ? s.substring(0, z) : s).trim();
  }

  static String _decodeUtf16(Uint8List bytes, {bool forceBE = false}) {
    if (bytes.length < 2) return '';
    var be = forceBE;
    var start = 0;
    if (!forceBE) {
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        be = true;
        start = 2;
      } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        be = false;
        start = 2;
      }
    }
    final units = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      final a = bytes[i], b = bytes[i + 1];
      units.add(be ? (a << 8) | b : (b << 8) | a);
    }
    return String.fromCharCodes(units);
  }

  static (Uint8List, String)? _parseApic(Uint8List data) {
    if (data.isEmpty) return null;
    final encByte = data[0];
    var pos = 1;
    // MIME type: null-terminated ISO-8859-1 (or Latin1 regardless of encByte).
    final mimeEnd = data.indexOf(0, pos);
    if (mimeEnd < 0) return null;
    final mime = latin1.decode(data.sublist(pos, mimeEnd));
    pos = mimeEnd + 1;
    pos += 1; // picture type byte
    // Description: null-terminated in the frame's text encoding.
    if (encByte == 1 || encByte == 2) {
      var i = pos;
      while (i + 1 < data.length && !(data[i] == 0 && data[i + 1] == 0)) {
        i += 2;
      }
      pos = i + 2;
    } else {
      final descEnd = data.indexOf(0, pos);
      pos = (descEnd < 0 ? pos : descEnd + 1);
    }
    if (pos > data.length) return null;
    return (data.sublist(pos), mime.isEmpty ? 'image/jpeg' : mime);
  }
}

class Id3Writer {
  /// Rewrites [file]'s ID3v2.3 tag with the given fields, preserving the
  /// original audio stream (everything after the old tag, or the whole file
  /// if it had none).
  static Future<void> write(
    File file, {
    required String title,
    required String artist,
    required String album,
    Uint8List? coverBytes,
    String? coverMime,
  }) async {
    final bytes = await file.readAsBytes();
    var audioStart = 0;
    if (bytes.length >= 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      final tagSize = Id3Reader._synchsafe(bytes.sublist(6, 10));
      audioStart = 10 + tagSize;
    }
    final audio = bytes.sublist(audioStart);

    final frames = BytesBuilder();
    frames.add(_textFrame('TIT2', title));
    frames.add(_textFrame('TPE1', artist));
    frames.add(_textFrame('TALB', album));
    if (coverBytes != null) {
      frames.add(_apicFrame(coverBytes, coverMime ?? 'image/jpeg'));
    }
    final frameBytes = frames.toBytes();

    final header = BytesBuilder();
    header.add(ascii.encode('ID3'));
    header.add([3, 0]); // v2.3.0
    header.add([0]); // flags
    header.add(_synchsafeEncode(frameBytes.length));

    final out = BytesBuilder();
    out.add(header.toBytes());
    out.add(frameBytes);
    out.add(audio);
    await file.writeAsBytes(out.toBytes(), flush: true);
  }

  static Uint8List _synchsafeEncode(int size) {
    return Uint8List.fromList([
      (size >> 21) & 0x7F,
      (size >> 14) & 0x7F,
      (size >> 7) & 0x7F,
      size & 0x7F,
    ]);
  }

  static Uint8List _textFrame(String id, String value) {
    final body = BytesBuilder();
    body.add([3]); // UTF-8 encoding
    body.add(utf8.encode(value));
    final data = body.toBytes();
    final out = BytesBuilder();
    out.add(ascii.encode(id));
    out.add(_frameSize(data.length));
    out.add([0, 0]); // flags
    out.add(data);
    return out.toBytes();
  }

  static Uint8List _apicFrame(Uint8List cover, String mime) {
    final body = BytesBuilder();
    body.add([3]); // UTF-8 encoding
    body.add(latin1.encode(mime));
    body.add([0]); // mime terminator
    body.add([3]); // picture type: front cover
    body.add([0]); // empty description + terminator
    body.add(cover);
    final data = body.toBytes();
    final out = BytesBuilder();
    out.add(ascii.encode('APIC'));
    out.add(_frameSize(data.length));
    out.add([0, 0]);
    out.add(data);
    return out.toBytes();
  }

  // ID3v2.3 frame sizes are plain 32-bit big-endian (not synchsafe) -
  // synchsafe sizes are a v2.4-only change.
  static Uint8List _frameSize(int size) {
    return Uint8List.fromList([
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ]);
  }
}
