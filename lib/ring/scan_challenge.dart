import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

enum _Phase { aim, scanning, found }

/// "Go find a cup." Live camera viewfinder.
///
/// TODO: verify the object on-device (e.g. ML Kit image labelling). For now
/// the scan always succeeds after a short "judging" delay, as in the design.
class ScanChallenge extends StatefulWidget {
  const ScanChallenge({super.key});
  @override
  State<ScanChallenge> createState() => _ScanChallengeState();
}

class _ScanChallengeState extends State<ScanChallenge> {
  final target = pick(scanObjects);
  _Phase phase = _Phase.aim;
  CameraController? _cam;
  bool _camFailed = false;
  Timer? _judge;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  Future<void> _openCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final cam = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await cam.initialize();
      if (!mounted) return await cam.dispose();
      setState(() => _cam = cam);
    } catch (_) {
      if (mounted) setState(() => _camFailed = true);
    }
  }

  @override
  void dispose() {
    _judge?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  void _action() {
    final session = context.read<RingSession>();
    session.poke();
    switch (phase) {
      case _Phase.aim:
        setState(() => phase = _Phase.scanning);
        _judge = Timer(const Duration(milliseconds: 2200), () => setState(() => phase = _Phase.found));
      case _Phase.scanning:
        break;
      case _Phase.found:
        session.win();
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = target.replaceFirst(RegExp(r'^(a|the|your) '), '');
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan challenge', style: AG.t(13, color: AG.muted)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(style: AG.d(34, height: 1.05), children: [
                    const TextSpan(text: 'Go find '),
                    TextSpan(text: target, style: const TextStyle(color: AG.pink)),
                    const TextSpan(text: '.'),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _viewfinder(),
                    ..._corners(),
                    if (phase == _Phase.scanning) const _ScanLine(),
                    if (phase == _Phase.found)
                      Container(
                        color: AG.bg.withValues(alpha: .55),
                        alignment: Alignment.center,
                        child: PopIn(
                          duration: const Duration(milliseconds: 500),
                          child: Transform.rotate(
                            angle: -4 * pi / 180,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              decoration:
                                  BoxDecoration(color: AG.lime, borderRadius: BorderRadius.circular(999)),
                              child: Text('Found $noun.', style: AG.d(22, color: AG.bg)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              children: [
                Text(
                  switch (phase) {
                    _Phase.aim => 'Point at it and hold steady.',
                    _Phase.scanning => 'Hold still. Judging…',
                    _Phase.found => 'Fine. You win this one.',
                  },
                  style: AG.t(13, color: AG.muted),
                ),
                const SizedBox(height: 10),
                Pill(
                  label: switch (phase) {
                    _Phase.aim => 'Scan',
                    _Phase.scanning => 'Scanning…',
                    _Phase.found => 'Done',
                  },
                  onTap: phase == _Phase.scanning ? null : _action,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    final cam = _cam;
    if (cam != null && cam.value.isInitialized) {
      final size = cam.value.previewSize;
      return size == null
          ? CameraPreview(cam)
          : FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: size.height, height: size.width, child: CameraPreview(cam)),
            );
    }
    return CustomPaint(
      painter: _StripesPainter(),
      child: Center(
        child: Text(
          _camFailed ? 'no camera access' : 'opening camera…',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AG.dim),
        ),
      ),
    );
  }

  List<Widget> _corners() {
    const side = BorderSide(color: AG.lime, width: 5);
    const r = Radius.circular(18);
    Widget corner({double? l, double? t, double? rt, double? b, required Border border, required BorderRadius radius}) =>
        Positioned(
          left: l,
          top: t,
          right: rt,
          bottom: b,
          child: Container(width: 44, height: 44, decoration: BoxDecoration(border: border, borderRadius: radius)),
        );
    return [
      corner(l: 18, t: 18, border: const Border(left: side, top: side), radius: const BorderRadius.only(topLeft: r)),
      corner(rt: 18, t: 18, border: const Border(right: side, top: side), radius: const BorderRadius.only(topRight: r)),
      corner(l: 18, b: 18, border: const Border(left: side, bottom: side), radius: const BorderRadius.only(bottomLeft: r)),
      corner(rt: 18, b: 18, border: const Border(right: side, bottom: side), radius: const BorderRadius.only(bottomRight: r)),
    ];
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, box) => AnimatedBuilder(
          animation: c,
          builder: (_, _) {
            final tri = c.value < .5 ? c.value * 2 : 2 - c.value * 2;
            final y = box.maxHeight * (.06 + .84 * Curves.easeInOut.transform(tri));
            return Stack(children: [
              Positioned(
                left: 24,
                right: 24,
                top: y,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AG.lime,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: AG.lime.withValues(alpha: .5), blurRadius: 24, spreadRadius: 6)],
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

/// The design's diagonal placeholder stripes.
class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AG.surface);
    final p = Paint()
      ..color = const Color(0xFF17171B)
      ..strokeWidth = 12 / sqrt2;
    for (double x = -size.height; x < size.width + size.height; x += 24 / sqrt2 * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
