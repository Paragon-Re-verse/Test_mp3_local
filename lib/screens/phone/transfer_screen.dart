import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/lan_device.dart';
import '../../state/player_app_state.dart';
import '../../theme/nocturne_theme.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final paired = state.paired;

    return Container(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Text(L.transfer, style: TextStyle(fontSize: 24, color: p.text, letterSpacing: -0.2)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (state.scanningDevices) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _Radar(color: p.accent, delay: Duration.zero),
                                _Radar(color: p.accent, delay: const Duration(seconds: 1)),
                                Icon(PhosphorIconsRegular.wifiHigh, size: 30, color: p.accent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(L.scanning, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  Text(L.devices.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, color: p.muted, fontFamily: kMonoFamily, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  ...state.discoveredDevices.map((d) => _DeviceRow(device: d)),
                  if (paired != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(border: Border.all(color: p.accent), borderRadius: BorderRadius.circular(8), color: p.accentDim),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(PhosphorIconsRegular.shieldCheck, size: 16, color: p.accent),
                            const SizedBox(width: 8),
                            Text('${L.paired} · ${paired.name}', style: TextStyle(fontSize: 12.5, color: p.accent)),
                          ]),
                          const SizedBox(height: 8),
                          Text(L.secure, style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: state.unpair,
                            style: OutlinedButton.styleFrom(foregroundColor: p.text, side: BorderSide(color: p.line)),
                            child: Text(L.unpair, style: const TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: state.rescan,
                      style: OutlinedButton.styleFrom(foregroundColor: p.muted, side: BorderSide(color: p.line)),
                      child: Text(L.rescan, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final LanDevice device;
  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlayerAppState>();
    final p = Theme.of(context).extension<NocturnePalette>()!;
    final L = state.L;
    final isPaired = state.paired?.id == device.id;
    final isPending = state.outgoingPairTargetId == device.id;
    final label = isPaired ? L.paired : (isPending ? L.waiting : L.pair);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isPaired || isPending ? null : () => state.tapDevice(device),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(device.kind.toLowerCase().contains('windows') ? PhosphorIconsRegular.desktopTower : PhosphorIconsRegular.deviceMobileSpeaker,
                  size: 22, color: p.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: TextStyle(fontSize: 13, color: p.text)),
                    const SizedBox(height: 3),
                    Text('${device.kind} · ${device.address}', style: TextStyle(fontSize: 10.5, color: p.muted, fontFamily: kMonoFamily)),
                  ],
                ),
              ),
              Text(label, style: TextStyle(fontSize: 11, color: p.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radar extends StatefulWidget {
  final Color color;
  final Duration delay;
  const _Radar({required this.color, required this.delay});
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 0.35 + _c.value * 1.35;
        final opacity = (1 - _c.value).clamp(0.0, 1.0) * 0.5;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color)),
            ),
          ),
        );
      },
    );
  }
}
