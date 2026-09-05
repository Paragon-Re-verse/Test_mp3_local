import 'dart:convert';
import 'dart:io';

import '../models/lan_device.dart';

/// Fired when a peer POSTs /pair/request to us.
class IncomingPairRequest {
  final LanDevice from;
  IncomingPairRequest(this.from);
}

/// Fired when a peer POSTs /pair/answer to us (we were the requester).
class PairAnswer {
  final String fromId;
  final bool accepted;
  PairAnswer(this.fromId, this.accepted);
}

/// Fired when a peer POSTs /control to us.
class RemoteCommand {
  final String fromId;
  final String cmd;
  final Map<String, dynamic> data;
  RemoteCommand(this.fromId, this.cmd, this.data);
}

/// HTTPS control-channel server: pairing handshake + playback/tag-sync
/// commands. Runs on an ephemeral port advertised via the discovery beacon.
class ControlServer {
  final SecurityContext securityContext;
  final void Function(IncomingPairRequest) onPairRequest;
  final void Function(PairAnswer) onPairAnswer;
  final void Function(RemoteCommand) onCommand;
  final bool Function(String peerId, String presentedFingerprint) isTrustedPeer;

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  ControlServer({
    required this.securityContext,
    required this.onPairRequest,
    required this.onPairAnswer,
    required this.onCommand,
    required this.isTrustedPeer,
  });

  Future<int> start() async {
    _server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      0,
      securityContext,
      requestClientCertificate: false,
    );
    _server!.listen(_handle, onError: (_) {});
    return _server!.port;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;

      switch (req.uri.path) {
        case '/health':
          req.response.statusCode = 200;
        case '/pair/request':
          final device = LanDevice(
            id: data['id'] as String,
            name: data['name'] as String,
            kind: data['kind'] as String? ?? '',
            address: req.connectionInfo?.remoteAddress.address ?? '',
            port: data['port'] as int? ?? 0,
            certFingerprint: data['fp'] as String? ?? '',
          );
          onPairRequest(IncomingPairRequest(device));
          req.response.statusCode = 202;
        case '/pair/answer':
          onPairAnswer(PairAnswer(data['id'] as String, data['accepted'] as bool? ?? false));
          req.response.statusCode = 200;
        case '/control':
          final fromId = data['fromId'] as String? ?? '';
          if (!isTrustedPeer(fromId, data['fp'] as String? ?? '')) {
            req.response.statusCode = 403;
            await req.response.close();
            return;
          }
          onCommand(RemoteCommand(fromId, data['cmd'] as String, (data['data'] as Map?)?.cast<String, dynamic>() ?? {}));
          req.response.statusCode = 200;
        default:
          req.response.statusCode = 404;
      }
    } catch (_) {
      req.response.statusCode = 400;
    }
    await req.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
