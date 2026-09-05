import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// This device's self-signed TLS identity for the local-network control
/// channel. Generated once and cached to disk - regenerating an RSA
/// keypair takes a couple of seconds, which we don't want to pay on every
/// launch.
class DeviceIdentity {
  final String certificatePem;
  final String privateKeyPem;
  final String fingerprintSha256;

  DeviceIdentity._(this.certificatePem, this.privateKeyPem, this.fingerprintSha256);

  /// [overrideDir] skips path_provider entirely - used by tests, which run
  /// outside a real platform embedder and need a distinct directory per
  /// simulated device.
  static Future<DeviceIdentity> loadOrCreate({required String deviceName, Directory? overrideDir}) async {
    final dir = overrideDir ?? await getApplicationSupportDirectory();
    final certFile = File(p.join(dir.path, 'nocturne_cert.pem'));
    final keyFile = File(p.join(dir.path, 'nocturne_key.pem'));

    if (await certFile.exists() && await keyFile.exists()) {
      final cert = await certFile.readAsString();
      final key = await keyFile.readAsString();
      final fp = _fingerprintOf(cert);
      if (fp != null) return DeviceIdentity._(cert, key, fp);
    }

    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;

    final csr = X509Utils.generateRsaCsrPem(
      {'CN': deviceName, 'O': 'Nocturne Local Player'},
      privateKey,
      publicKey,
    );
    final certPem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      3650,
      sans: ['localhost'],
    );
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    await dir.create(recursive: true);
    await certFile.writeAsString(certPem);
    await keyFile.writeAsString(keyPem);

    final fp = _fingerprintOf(certPem)!;
    return DeviceIdentity._(certPem, keyPem, fp);
  }

  static String? _fingerprintOf(String certPem) {
    try {
      final der = CryptoUtils.getBytesFromPEMString(certPem);
      final digest = sha256.convert(der);
      return _hexColonSeparated(Uint8List.fromList(digest.bytes));
    } catch (_) {
      return null;
    }
  }

  static String _hexColonSeparated(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}
