/// A device seen on the local network (via our UDP discovery beacon), or
/// paired with, mirroring the "Передача" (Transfer) screen in the
/// prototype: id/name/kind/address plus pairing + fingerprint state.
class LanDevice {
  final String id;
  final String name;
  final String kind; // e.g. "Windows 11", "Android"
  final String address;
  final int port;
  final String certFingerprint;

  const LanDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.address,
    required this.port,
    required this.certFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'address': address,
    'port': port,
    'certFingerprint': certFingerprint,
  };

  factory LanDevice.fromJson(Map<String, dynamic> j) => LanDevice(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: j['kind'] as String,
    address: j['address'] as String,
    port: j['port'] as int,
    certFingerprint: j['certFingerprint'] as String? ?? '',
  );
}
