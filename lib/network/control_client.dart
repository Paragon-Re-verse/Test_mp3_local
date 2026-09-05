import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/lan_device.dart';

/// Client for the HTTPS control channel. Certificate trust is
/// trust-on-first-use: the fingerprint offered in a discovery beacon /
/// pairing request is shown to the user, and once paired we pin it - every
/// later connection to that peer must present the same fingerprint.
class ControlClient {
  final String Function(String peerId) pinnedFingerprintFor;

  ControlClient({required this.pinnedFingerprintFor});

  static String fingerprintOf(X509Certificate cert) {
    final digest = sha256.convert(cert.der);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  Future<bool> _post(LanDevice device, String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    client.badCertificateCallback = (cert, host, port) {
      final pinned = pinnedFingerprintFor(device.id);
      if (pinned.isEmpty) return true; // first contact: nothing pinned yet
      return fingerprintOf(cert) == pinned;
    };
    try {
      final req = await client.postUrl(Uri.parse('https://${device.address}:${device.port}$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      await res.drain();
      return res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> requestPair(
    LanDevice target, {
    required String myId,
    required String myName,
    required String myKind,
    required int myPort,
    required String myFingerprint,
  }) {
    return _post(target, '/pair/request', {
      'id': myId,
      'name': myName,
      'kind': myKind,
      'port': myPort,
      'fp': myFingerprint,
    });
  }

  Future<bool> answerPair(LanDevice requester, {required bool accepted, required String myId}) {
    return _post(requester, '/pair/answer', {'id': myId, 'accepted': accepted});
  }

  Future<bool> sendCommand(
    LanDevice peer,
    String cmd,
    Map<String, dynamic> data, {
    required String myId,
    required String myFingerprint,
  }) {
    return _post(peer, '/control', {'fromId': myId, 'fp': myFingerprint, 'cmd': cmd, 'data': data});
  }
}
