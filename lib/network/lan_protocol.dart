/// Shared constants + message shapes for the local-network protocol.
///
/// Design (kept intentionally simple over the full mDNS/DNS-SD spec, since
/// we control both ends and only need "who's on my LAN running Nocturne"):
///
/// - Discovery: a UDP broadcast beacon on [discoveryPort]. Each device
///   periodically announces {id, name, kind, controlPort} while a scan is
///   active; anyone listening builds a "seen recently" device list.
/// - Control: a per-device HTTPS server on an ephemeral port (advertised in
///   the beacon) handles pairing requests/answers and playback/tag-sync
///   commands, authenticated by TLS + a trust-on-first-use certificate
///   fingerprint pinned at pairing time.
/// - Streaming: a plain HTTP server on a second ephemeral port serves audio
///   bytes (with Range support) under a random per-launch token, so a
///   paired device can point its player straight at a URL without needing
///   to trust the self-signed cert for bulk audio transfer.
class LanProtocol {
  static const int discoveryPort = 48695;
  static const String beaconAppId = 'nocturne-local-player';
  static const Duration beaconInterval = Duration(seconds: 1);
  static const Duration deviceTtl = Duration(seconds: 6);
}

String deviceKindForPlatform({required bool isDesktop, String osLabel = ''}) {
  return isDesktop ? 'Windows${osLabel.isEmpty ? '' : ' $osLabel'}' : 'Android';
}
