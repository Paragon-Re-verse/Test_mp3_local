import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nocturne_player/network/identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('raw HTTPS round trip with a generated self-signed cert', () async {
    final dir = await Directory.systemTemp.createTemp('identity_smoke');
    final identity = await DeviceIdentity.loadOrCreate(deviceName: 'smoke-test', overrideDir: dir);
    // ignore: avoid_print
    print('cert length: ${identity.certificatePem.length}, key length: ${identity.privateKeyPem.length}');
    // ignore: avoid_print
    print('fingerprint: ${identity.fingerprintSha256}');

    final ctx = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));

    final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    server.listen((req) async {
      req.response.statusCode = 200;
      req.response.write('ok');
      await req.response.close();
    });

    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    final req = await client.getUrl(Uri.parse('https://127.0.0.1:${server.port}/'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    // ignore: avoid_print
    print('status: ${res.statusCode}, body: $body');
    expect(res.statusCode, 200);
    expect(body, 'ok');

    await server.close(force: true);
    await dir.delete(recursive: true);
  });
}
