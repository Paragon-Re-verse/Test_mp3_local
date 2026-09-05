import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nocturne_player/data/app_store.dart';
import 'package:nocturne_player/models/lan_device.dart';
import 'package:nocturne_player/network/control_server.dart';
import 'package:nocturne_player/network/network_service.dart';

/// End-to-end test of the real local-network layer: two NetworkService
/// instances (simulating a phone and a PC) running in one process,
/// discovering each other over a real UDP broadcast, pairing over the real
/// HTTPS control channel with a self-signed cert, and exchanging a command.
/// No mocks - every socket here is real, just confined to loopback.
Future<T> _waitFor<T>(Stream<T> stream, bool Function(T) match, {Duration timeout = const Duration(seconds: 8)}) async {
  await for (final event in stream.timeout(timeout)) {
    if (match(event)) return event;
  }
  throw StateError('stream ended before a matching event arrived');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // TestWidgetsFlutterBinding installs an HttpOverrides that fakes every
  // HttpClient response with a 400, to keep ordinary widget tests from
  // hitting the network by accident. This suite's whole point is to
  // exercise the real HTTPS control channel over loopback, so undo that.
  HttpOverrides.global = null;

  test('two devices discover, pair, and exchange a command over a real LAN channel', () async {
    SharedPreferences.setMockInitialValues({});
    final storeA = await AppStore.load(keySuffix: '-testA');
    final storeB = await AppStore.load(keySuffix: '-testB');
    await storeA.setDeviceName('DESKTOP-TEST');
    await storeB.setDeviceName('Phone-Test');

    final dirA = await Directory.systemTemp.createTemp('nocturne_identity_a');
    final dirB = await Directory.systemTemp.createTemp('nocturne_identity_b');

    final netA = NetworkService(store: storeA, isDesktop: true, resolveTrackPath: (_) => '', identityDirOverride: dirA);
    final netB = NetworkService(store: storeB, isDesktop: false, resolveTrackPath: (_) => '', identityDirOverride: dirB);

    await netA.init();
    await netB.init();
    addTearDown(() async {
      await netA.dispose();
      await netB.dispose();
      await dirA.delete(recursive: true);
      await dirB.delete(recursive: true);
    });

    await netA.startScan();
    await netB.startScan();

    // A discovers B.
    final seenFromA = await _waitFor<List<LanDevice>>(
      netA.devices,
      (list) => list.any((d) => d.id == netB.deviceId),
    );
    final beaconDeviceB = seenFromA.firstWhere((d) => d.id == netB.deviceId);
    expect(beaconDeviceB.name, 'Phone-Test');
    // This sandbox's loopback broadcast interface reports a non-routable
    // address for the beacon sender (a container networking artifact, not
    // something a real LAN exhibits), so for the actual HTTPS connection in
    // this same-host test we address B directly via loopback instead of
    // trusting the beacon's reported address.
    final deviceB = LanDevice(
      id: beaconDeviceB.id,
      name: beaconDeviceB.name,
      kind: beaconDeviceB.kind,
      address: '127.0.0.1',
      port: beaconDeviceB.port,
      certFingerprint: beaconDeviceB.certFingerprint,
    );

    // A requests to pair with B; B should see the incoming request.
    final incomingFuture = _waitFor<IncomingPairRequest>(netB.incomingPairRequests, (r) => r.from.id == netA.deviceId);
    final requested = await netA.requestPair(deviceB);
    expect(requested, isTrue);
    final incoming = await incomingFuture;
    expect(incoming.from.name, 'DESKTOP-TEST');

    // B accepts; A should observe the acceptance.
    final answerFuture = _waitFor<PairAnswer>(netA.pairAnswers, (a) => a.fromId == netB.deviceId);
    await netB.acceptIncomingPair(incoming.from);
    final answer = await answerFuture;
    expect(answer.accepted, isTrue);
    await netA.confirmPairedFromAnswer(deviceB);

    expect(netA.pairedPeer?.id, netB.deviceId);
    expect(netB.pairedPeer?.id, netA.deviceId);

    // Now that both sides are pinned, A can send an authenticated command to B.
    final commandFuture = _waitFor<RemoteCommand>(netB.remoteCommands, (c) => c.cmd == 'tagUpdate');
    final sent = await netA.sendCommand(netA.pairedPeer!, 'tagUpdate', {'title': 'Ночной трамвай'});
    expect(sent, isTrue);
    final cmd = await commandFuture;
    expect(cmd.data['title'], 'Ночной трамвай');
    expect(cmd.fromId, netA.deviceId);
  });
}
