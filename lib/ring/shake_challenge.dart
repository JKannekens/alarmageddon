import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

/// Shake the phone N times (N depends on difficulty).
class ShakeChallenge extends StatefulWidget {
  const ShakeChallenge({super.key});
  @override
  State<ShakeChallenge> createState() => _ShakeChallengeState();
}

class _ShakeChallengeState extends State<ShakeChallenge> {
  /// m/s² of user acceleration (gravity removed) that counts as a shake.
  static const _threshold = 14.0;
  static const _debounce = Duration(milliseconds: 220);

  late final RingSession session = context.read<RingSession>();
  late final int target = session.difficulty.shakes;
  int count = 0;
  bool sawSensor = false;
  bool showFallback = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<UserAccelerometerEvent>? _sub;
  Timer? _sensorCheck;

  @override
  void initState() {
    super.initState();
    try {
      _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        _onMotion,
        onError: (_) => setState(() => showFallback = true),
        cancelOnError: true,
      );
    } catch (_) {
      showFallback = true;
    }
    // Only offer tap-to-shake when the device has no motion sensor at all.
    _sensorCheck = Timer(const Duration(milliseconds: 1500), () {
      if (!sawSensor && mounted) setState(() => showFallback = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sensorCheck?.cancel();
    super.dispose();
  }

  void _onMotion(UserAccelerometerEvent e) {
    sawSensor = true;
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (mag > _threshold && now.difference(_last) > _debounce) {
      _last = now;
      _add();
    }
  }

  void _add() {
    if (count >= target) return;
    session.poke();
    setState(() => count++);
    if (count >= target) Future.delayed(const Duration(milliseconds: 300), session.win);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (count / target).clamp(0.0, 1.0);
    final msg = count == 0
        ? 'Grab the phone. Shake it hard.'
        : count < target / 2
            ? "Harder. I've seen leaves shake more."
            : count < target
                ? "Almost. Don't throw me."
                : "That's enough, you maniac.";
    final body = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shake challenge', style: AG.t(13, color: AG.muted)),
                const SizedBox(height: 2),
                Text('Shake me like you mean it.', style: AG.d(34, height: 1.05)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(
                  painter: _RingPainter(pct),
                  child: Center(
                    child: Container(
                      width: 212,
                      height: 212,
                      decoration: const BoxDecoration(color: AG.bg, shape: BoxShape.circle),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$count', style: AG.d(84, color: AG.lime, height: 1)),
                          Text('of $target shakes', style: AG.t(13, color: AG.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              children: [
                Text(msg, textAlign: TextAlign.center, style: AG.t(14, height: 1.35)),
                if (showFallback) ...[
                  const SizedBox(height: 10),
                  Pill(
                    label: 'No motion sensor? Tap to shake',
                    bg: AG.surface,
                    fg: AG.muted,
                    padding: const EdgeInsets.all(16),
                    style: AG.t(14, weight: FontWeight.w700),
                    onTap: _add,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    // Each shake jolts the whole screen once.
    return count == 0
        ? body
        : Jitter(key: ValueKey(count), period: const Duration(milliseconds: 150), repeats: 1, amount: 3, child: body);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.pct);
  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(rect.center, size.width / 2, Paint()..color = AG.surface);
    canvas.drawArc(rect, -pi / 2, 2 * pi * pct, true, Paint()..color = AG.lime);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct;
}
