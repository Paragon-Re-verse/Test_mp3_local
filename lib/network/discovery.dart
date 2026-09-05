import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/lan_device.dart';
import 'lan_protocol.dart';

/// Real Android hardware silently drops incoming broadcast/multicast UDP
/// datagrams while the WiFi radio is in power-save mode unless the app
/// holds a WifiManager.MulticastLock (acquired natively - see
/// MainActivity.kt). Without it, discovery works in emulators/desktop but
/// finds nothing on a real phone. This is a no-op (and safely ignored) on
/// platforms other than Android.
const _multicastLockChannel = MethodChannel('nocturne/multicast_lock');

Future<void> _acquireMulticastLock() async {
  if (!Platform.isAndroid) return;
  try {
    await _multicastLockChannel.invokeMethod('acquire');
  } catch (_) {
    // Best-effort: discovery still works via emulators/desktop and on
    // devices where the radio doesn't filter it.
  }
}

Future<void> _releaseMulticastLock() async {
  if (!Platform.isAndroid) return;
  try {
    await _multicastLockChannel.invokeMethod('release');
  } catch (_) {
    // Best-effort.
  }
}

/// UDP broadcast discovery: announces this device and listens for others.
class LanDiscovery {
  final String selfId;
  final String selfName;
  final String selfKind;
  final int controlPort;
  final String selfFingerprint;

  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _expiryTimer;
  final _devices = <String, _Seen>{};
  final _controller = StreamController<List<LanDevice>>.broadcast();

  LanDiscovery({
    required this.selfId,
    required this.selfName,
    required this.selfKind,
    required this.controlPort,
    required this.selfFingerprint,
  });

  Stream<List<LanDevice>> get devices => _controller.stream;

  Future<void> start() async {
    await _acquireMulticastLock();
    // reuseAddress/reusePort: lets more than one instance on the same host
    // receive broadcast beacons (harmless in production - a real device
    // only ever runs one instance - and required for tests, which run
    // multiple NetworkService instances in one process to simulate peers).
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      LanProtocol.discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen(_onDatagram);
    _beaconTimer = Timer.periodic(LanProtocol.beaconInterval, (_) => _sendBeacon());
    _expiryTimer = Timer.periodic(const Duration(seconds: 2), (_) => _expireStale());
    _sendBeacon();
  }

  void _sendBeacon() {
    final socket = _socket;
    if (socket == null) return;
    final payload = utf8.encode(jsonEncode({
      'app': LanProtocol.beaconAppId,
      'id': selfId,
      'name': selfName,
      'kind': selfKind,
      'port': controlPort,
      'fp': selfFingerprint,
    }));
    try {
      socket.send(payload, InternetAddress('255.255.255.255'), LanProtocol.discoveryPort);
    } catch (_) {
      // Best-effort; some sandboxes/networks reject broadcast sends.
    }
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    try {
      final msg = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (msg['app'] != LanProtocol.beaconAppId) return;
      final id = msg['id'] as String?;
      if (id == null || id == selfId) return;
      _devices[id] = _Seen(
        LanDevice(
          id: id,
          name: msg['name'] as String? ?? id,
          kind: msg['kind'] as String? ?? '',
          address: dg.address.address,
          port: msg['port'] as int? ?? 0,
          certFingerprint: msg['fp'] as String? ?? '',
        ),
        DateTime.now(),
      );
      _emit();
    } catch (_) {
      // Ignore malformed packets from other apps on the same port.
    }
  }

  void _expireStale() {
    final now = DateTime.now();
    final before = _devices.length;
    _devices.removeWhere((_, seen) => now.difference(seen.at) > LanProtocol.deviceTtl);
    if (_devices.length != before) _emit();
  }

  void _emit() {
    _controller.add(_devices.values.map((s) => s.device).toList());
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _expiryTimer?.cancel();
    _socket?.close();
    _socket = null;
    _devices.clear();
    await _releaseMulticastLock();
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

class _Seen {
  final LanDevice device;
  final DateTime at;
  _Seen(this.device, this.at);
}
