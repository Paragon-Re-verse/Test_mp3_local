import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/lan_device.dart';
import 'control_client.dart';
import 'control_server.dart';
import 'discovery.dart';
import 'identity.dart';
import 'lan_protocol.dart';
import 'stream_server.dart';

/// Wires discovery + the HTTPS control channel + the HTTP audio-stream
/// server into one facade the app state talks to. No external servers are
/// ever contacted - every socket here is bound to the LAN only.
class NetworkService {
  final AppStore store;
  final bool isDesktop;
  final String Function(String trackId) resolveTrackPath;

  /// Test-only escape hatch - see [DeviceIdentity.loadOrCreate].
  final Directory? identityDirOverride;

  NetworkService({
    required this.store,
    required this.isDesktop,
    required this.resolveTrackPath,
    this.identityDirOverride,
  });

  late String deviceId;
  late String deviceName;
  late DeviceIdentity identity;
  LanDiscovery? _discovery;
  ControlServer? _controlServer;
  StreamServer? _streamServer;
  late ControlClient _controlClient;

  LanDevice? _pinnedPeer;

  final _devicesController = StreamController<List<LanDevice>>.broadcast();
  final _incomingPairController = StreamController<IncomingPairRequest>.broadcast();
  final _pairAnswerController = StreamController<PairAnswer>.broadcast();
  final _commandController = StreamController<RemoteCommand>.broadcast();

  Stream<List<LanDevice>> get devices => _devicesController.stream;
  Stream<IncomingPairRequest> get incomingPairRequests => _incomingPairController.stream;
  Stream<PairAnswer> get pairAnswers => _pairAnswerController.stream;
  Stream<RemoteCommand> get remoteCommands => _commandController.stream;

  Future<void> init() async {
    deviceId = await _loadOrCreateDeviceId();
    deviceName = await store.deviceName;
    identity = await DeviceIdentity.loadOrCreate(deviceName: deviceName, overrideDir: identityDirOverride);

    final pairedJson = await store.pairedDevice;
    if (pairedJson != null) _pinnedPeer = LanDevice.fromJson(pairedJson);

    _controlClient = ControlClient(pinnedFingerprintFor: (peerId) {
      return _pinnedPeer?.id == peerId ? _pinnedPeer!.certFingerprint : '';
    });

    _controlServer = ControlServer(
      securityContext: SecurityContext()
        ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem)),
      onPairRequest: (r) => _incomingPairController.add(r),
      onPairAnswer: (a) => _pairAnswerController.add(a),
      onCommand: (c) => _commandController.add(c),
      isTrustedPeer: (peerId, fp) => _pinnedPeer?.id == peerId && _pinnedPeer?.certFingerprint == fp,
    );
    final controlPort = await _controlServer!.start();

    _streamServer = StreamServer(resolvePath: resolveTrackPath);
    await _streamServer!.start();

    _discovery = LanDiscovery(
      selfId: deviceId,
      selfName: deviceName,
      selfKind: deviceKindForPlatform(isDesktop: isDesktop),
      controlPort: controlPort,
      selfFingerprint: identity.fingerprintSha256,
    );
    _discovery!.devices.listen(_devicesController.add);
  }

  Future<String> _loadOrCreateDeviceId() async {
    final existing = await store.networkIdentity;
    if (existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await store.setNetworkIdentity(id);
    return id;
  }

  Future<void> startScan() => _discovery?.start() ?? Future.value();
  Future<void> stopScan() => _discovery?.stop() ?? Future.value();

  Future<bool> requestPair(LanDevice target) {
    return _controlClient.requestPair(
      target,
      myId: deviceId,
      myName: deviceName,
      myKind: deviceKindForPlatform(isDesktop: isDesktop),
      myPort: _controlServer?.port ?? 0,
      myFingerprint: identity.fingerprintSha256,
    );
  }

  Future<void> acceptIncomingPair(LanDevice requester) async {
    _pinnedPeer = requester;
    await store.setPairedDevice(requester.toJson());
    await _controlClient.answerPair(requester, accepted: true, myId: deviceId);
  }

  Future<void> declineIncomingPair(LanDevice requester) {
    return _controlClient.answerPair(requester, accepted: false, myId: deviceId);
  }

  Future<void> confirmPairedFromAnswer(LanDevice device) async {
    _pinnedPeer = device;
    await store.setPairedDevice(device.toJson());
  }

  Future<void> unpair() async {
    _pinnedPeer = null;
    await store.setPairedDevice(null);
  }

  LanDevice? get pairedPeer => _pinnedPeer;

  Future<bool> sendCommand(LanDevice peer, String cmd, Map<String, dynamic> data) {
    return _controlClient.sendCommand(peer, cmd, data, myId: deviceId, myFingerprint: identity.fingerprintSha256);
  }

  /// Builds a URL the given peer can use to stream [trackId]'s audio bytes
  /// straight off this device, for the audio-output handoff feature.
  Future<String?> streamUrlFor(String trackId) async {
    final ip = await _localIPv4();
    if (ip == null || _streamServer == null) return null;
    return 'http://$ip:${_streamServer!.port}/stream/${_streamServer!.token}/${Uri.encodeComponent(trackId)}';
  }

  Future<String?> _localIPv4() async {
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _discovery?.stop();
    _discovery?.dispose();
    await _controlServer?.stop();
    await _streamServer?.stop();
    await _devicesController.close();
    await _incomingPairController.close();
    await _pairAnswerController.close();
    await _commandController.close();
  }
}
