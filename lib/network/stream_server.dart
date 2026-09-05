import 'dart:io';
import 'dart:math';

/// Plain-HTTP file server for audio bytes, with Range support so a peer's
/// player can seek. Kept separate from the HTTPS control channel (see
/// lan_protocol.dart doc comment for why) and gated by a random per-launch
/// token so it isn't a wide-open file server to anyone on the LAN.
class StreamServer {
  final String Function(String trackId) resolvePath;

  HttpServer? _server;
  late final String token;
  int get port => _server?.port ?? 0;

  StreamServer({required this.resolvePath}) {
    token = _randomToken();
  }

  static String _randomToken() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
  }

  Future<int> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle, onError: (_) {});
    return _server!.port;
  }

  Future<void> _handle(HttpRequest req) async {
    final segments = req.uri.pathSegments;
    if (segments.length < 3 || segments[0] != 'stream' || segments[1] != token) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final trackId = Uri.decodeComponent(segments.sublist(2).join('/'));
    final path = resolvePath(trackId);
    final file = File(path);
    if (path.isEmpty || !await file.exists()) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }

    final length = await file.length();
    final range = req.headers.value(HttpHeaders.rangeHeader);
    req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    req.response.headers.set(HttpHeaders.contentTypeHeader, 'audio/mpeg');

    if (range != null && range.startsWith('bytes=')) {
      final parts = range.substring(6).split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty) ? int.parse(parts[1]) : length - 1;
      final clampedEnd = min(end, length - 1);
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$clampedEnd/$length');
      req.response.contentLength = clampedEnd - start + 1;
      await req.response.addStream(file.openRead(start, clampedEnd + 1));
    } else {
      req.response.contentLength = length;
      await req.response.addStream(file.openRead());
    }
    await req.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
