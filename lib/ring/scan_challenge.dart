import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../models.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';
import 'scan_judge.dart';

enum _Phase { aim, scanning, found }

/// "Go find a cup." Live camera viewfinder; on-device image labelling (ML Kit)
/// checks the thing is really in shot.
///
/// Labelling only runs on Android and iOS. Where it can't run (web, no camera,
/// camera denied) the way out is math, so there's no free win. To preview the
/// scan UI anyway, build with `--dart-define=FAKE_SCAN=true`: every scan then
/// passes after a short "judging" delay, as in the design.
class ScanChallenge extends StatefulWidget {
  const ScanChallenge({super.key});

  /// Skip the labeller and pass every scan. For UI previews and tests.
  static bool fake = const bool.fromEnvironment('FAKE_SCAN');

  @override
  State<ScanChallenge> createState() => _ScanChallengeState();
}

class _ScanChallengeState extends State<ScanChallenge> {
  /// How long one scan looks before calling it a miss.
  static const _attempt = Duration(seconds: 6);

  /// Misses before math is offered instead (bad light, or a thing the model
  /// just doesn't know).
  static const _missesBeforeMath = 3;

  static const _deviceTurns = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  late final RingSession session = context.read<RingSession>();
  final target = pick(scanTargets);
  late final judge = ScanJudge(target);
  _Phase phase = _Phase.aim;
  CameraController? _cam;
  bool _camFailed = false;
  ImageLabeler? _labeler;
  bool _busy = false;
  bool _torch = false;
  bool _torchFailed = false;
  int _misses = 0;
  Timer? _timeout;
  Future<void>? _stopping;

  bool get _canLabel =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  bool get _canScan => ScanChallenge.fake || (_canLabel && !_camFailed);

  @override
  void initState() {
    super.initState();
    if (_canScan) _openCamera();
  }

  Future<void> _openCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final cam = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        // The stream formats ML Kit reads directly.
        imageFormatGroup:
            defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await cam.initialize();
      if (!mounted) return await cam.dispose();
      setState(() => _cam = cam);
    } catch (_) {
      if (mounted) setState(() => _camFailed = true);
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _cam?.dispose();
    _labeler?.close().catchError((_) {});
    super.dispose();
  }

  void _action() {
    session.poke();
    switch (phase) {
      case _Phase.aim:
        setState(() => phase = _Phase.scanning);
        if (ScanChallenge.fake) {
          _timeout = Timer(const Duration(milliseconds: 2200), _found);
        } else {
          _startScan();
        }
      case _Phase.scanning:
        break;
      case _Phase.found:
        session.win();
    }
  }

  Future<void> _startScan() async {
    judge.reset();
    _labeler ??= ImageLabeler(options: ImageLabelerOptions());
    _timeout = Timer(_attempt, _miss);
    try {
      await _stopping; // the last scan's stream may still be shutting down
      if (phase == _Phase.scanning) await _cam!.startImageStream(_onFrame);
    } catch (_) {
      _miss();
    }
  }

  void _stopScan() {
    _timeout?.cancel();
    final cam = _cam;
    if (cam != null && cam.value.isStreamingImages) _stopping = cam.stopImageStream().catchError((_) {});
  }

  void _found() {
    if (!mounted || phase != _Phase.scanning) return;
    _stopScan();
    setState(() => phase = _Phase.found);
  }

  void _miss() {
    if (!mounted || phase != _Phase.scanning) return;
    _stopScan();
    setState(() {
      phase = _Phase.aim;
      _misses++;
    });
  }

  Future<void> _onFrame(CameraImage frame) async {
    final labeler = _labeler;
    if (_busy || labeler == null || phase != _Phase.scanning) return;
    final input = _inputImage(frame);
    if (input == null) return;
    _busy = true;
    try {
      final labels = await labeler.processImage(input);
      if (kDebugMode) {
        debugPrint('scan: ${labels.map((l) => '${l.label} ${l.confidence.toStringAsFixed(2)}').join(', ')}');
      }
      if (!mounted || phase != _Phase.scanning) return;
      session.poke();
      if (judge.add(labels, DateTime.now())) _found();
    } catch (_) {
      // One dropped frame isn't worth failing the scan over.
    } finally {
      _busy = false;
    }
  }

  /// Wraps a camera frame for ML Kit, as in google_mlkit_commons' README.
  /// Android reads the rotation; iOS reads the row stride.
  InputImage? _inputImage(CameraImage frame) {
    final cam = _cam!;
    final sensor = cam.description.sensorOrientation;
    final turn = _deviceTurns[cam.value.deviceOrientation] ?? 0;
    final degrees = defaultTargetPlatform == TargetPlatform.iOS
        ? sensor
        : cam.description.lensDirection == CameraLensDirection.front
            ? (sensor + turn) % 360
            : (sensor - turn + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);
    if (rotation == null || format == null || frame.planes.length != 1) return null;
    final plane = frame.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _toggleTorch() async {
    final cam = _cam;
    if (cam == null) return;
    session.poke();
    try {
      await cam.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) setState(() => _torchFailed = true);
    }
  }

  void _toMath() => session.switchTo(Challenge.math);

  @override
  Widget build(BuildContext context) {
    final noun = target.name.replaceFirst(RegExp(r'^(a|the|your) '), '');
    final canScan = _canScan;
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
                    TextSpan(text: target.name, style: const TextStyle(color: AG.pink)),
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
                    if (_cam != null && !_torchFailed && phase != _Phase.found)
                      Positioned(left: 0, right: 0, bottom: 22, child: Center(child: _torchButton())),
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
                  !canScan
                      ? "No camera, no scan. You're doing math."
                      : switch (phase) {
                          _Phase.aim when _misses > 0 => 'No $noun in sight. Closer, or hit the light.',
                          _Phase.aim => 'Point at it and hold steady.',
                          _Phase.scanning => 'Hold still. Judging…',
                          _Phase.found => 'Fine. You win this one.',
                        },
                  style: AG.t(13, color: AG.muted),
                ),
                const SizedBox(height: 10),
                if (!canScan)
                  Pill(label: 'Do the math', onTap: _toMath)
                else
                  Pill(
                    label: switch (phase) {
                      _Phase.aim => 'Scan',
                      _Phase.scanning => 'Scanning…',
                      _Phase.found => 'Done',
                    },
                    onTap: phase == _Phase.scanning || (_cam == null && !ScanChallenge.fake) ? null : _action,
                  ),
                if (canScan && phase == _Phase.aim && _misses >= _missesBeforeMath)
                  GestureDetector(
                    onTap: _toMath,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text("Can't find it? Do math instead", style: AG.t(12, color: AG.muted)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _torchButton() => Pressable(
        onTap: _toggleTorch,
        semanticLabel: _torch ? 'Light off' : 'Light on',
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: _torch ? AG.lime : AG.bg.withValues(alpha: .6), shape: BoxShape.circle),
          child: Icon(
            _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
            color: _torch ? AG.bg : AG.ink,
          ),
        ),
      );

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
          _camFailed
              ? 'no camera access'
              : _canScan
                  ? 'opening camera…'
                  : 'no scanner here',
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
