import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

class RingScreen extends StatefulWidget {
  const RingScreen({super.key});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> with SingleTickerProviderStateMixin {
  static const _rowH = 56.0;
  late final AnimationController _reel = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  Timer? _reelStart;
  Timer? _strobe;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _reelStart = Timer(const Duration(milliseconds: 80), () => _reel.forward());
    if (context.read<RingSession>().flash) {
      // Roughly one flash a second: well under the 3 Hz photosensitivity limit.
      _strobe = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        setState(() => _flashOn = true);
        Future.delayed(const Duration(milliseconds: 90), () {
          if (mounted) setState(() => _flashOn = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _reelStart?.cancel();
    _strobe?.cancel();
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RingSession>();
    final skipsLeft = s.store.skipsLeft;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final cx = w / 2, cy = h * .485;
      final top = MediaQuery.paddingOf(context).top;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: cx - 260, top: cy - 260, child: Pulse(child: Dot(size: 520, color: AG.limeTint(.18)))),
          Positioned(
            left: cx - 200,
            top: cy - 200,
            child: Pulse(delay: const Duration(milliseconds: 330), child: Dot(size: 400, color: AG.limeTint(.40))),
          ),
          Positioned(
            left: cx - 140,
            top: cy - 140,
            child: const Pulse(period: Duration(milliseconds: 650), child: Dot(size: 280, color: AG.lime)),
          ),
          for (final d in const [0, 650, 1300])
            Positioned(
              left: cx - 140,
              top: cy - 140,
              child: Ripple(size: 280, color: AG.lime, delay: Duration(milliseconds: d)),
            ),
          Positioned(
            left: -40,
            right: -40,
            top: top + 60,
            child: const Marquee(text: 'GET UP', background: AG.pink, foreground: AG.bg, angle: -6),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: top + 8,
            child: Text(s.roastLine, style: AG.t(15, height: 1.35)),
          ),
          Positioned(
            left: -40,
            right: -40,
            top: h * .64,
            child: const Marquee(
              text: 'SNOOZE IS FOR QUITTERS',
              background: AG.ink,
              foreground: AG.bg,
              angle: 5,
              seconds: 12,
              reverse: true,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: cy - 50,
            child: Center(
              child: Jitter(
                child: Text(
                  formatClock(s.alarm.hour, s.alarm.minute),
                  style: AG.d(88, color: AG.bg, height: 1).copyWith(
                    shadows: const [Shadow(color: AG.pink, offset: Offset(3, 0))],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28 + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.isTest ? "TODAY'S PUNISHMENT · TEST RUN" : "TODAY'S PUNISHMENT",
                  textAlign: TextAlign.center,
                  style: AG.label.copyWith(color: AG.pink),
                ),
                const SizedBox(height: 6),
                _Reel(session: s, controller: _reel, rowHeight: _rowH),
                const SizedBox(height: 12),
                if (s.spinning)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AG.surfaceHi, borderRadius: BorderRadius.circular(999)),
                    child: Text('Rolling…', textAlign: TextAlign.center, style: AG.d(19, color: AG.muted)),
                  )
                else
                  PopIn(child: Wobble(child: Pill(label: s.rolled.cta, onTap: s.startChallenge))),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: s.openSkipSheet,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Emergency skip · burns ${s.store.streak} days',
                      textAlign: TextAlign.center,
                      style: AG.t(12, color: AG.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (s.sheetOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: s.closeSkipSheet,
                child: Container(color: AG.bg.withValues(alpha: .7)),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _SkipSheet(session: s, skipsLeft: skipsLeft)),
          ],
          if (_flashOn) Positioned.fill(child: IgnorePointer(child: Container(color: Colors.white.withValues(alpha: .85)))),
        ],
      );
    });
  }
}

class _Reel extends StatelessWidget {
  const _Reel({required this.session, required this.controller, required this.rowHeight});
  final RingSession session;
  final AnimationController controller;
  final double rowHeight;

  static const _curve = Cubic(.12, .75, .18, 1);

  @override
  Widget build(BuildContext context) {
    final reel = session.reel;
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: AG.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: session.spinning ? Colors.transparent : AG.lime, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (_, _) => OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: Transform.translate(
                  offset: Offset(0, -(reel.length - 1) * rowHeight * _curve.transform(controller.value) - 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, c) in reel.indexed)
                        SizedBox(
                          height: rowHeight,
                          child: Center(
                            child: Text(
                              c.label,
                              style: AG.d(24,
                                  color: i == reel.length - 1 && !session.spinning ? AG.lime : AG.ink),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AG.surface, Color(0x001C1C21), Color(0x001C1C21), AG.surface],
                      stops: [0, .3, .7, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipSheet extends StatelessWidget {
  const _SkipSheet({required this.session, required this.skipsLeft});
  final RingSession session;
  final int skipsLeft;

  @override
  Widget build(BuildContext context) {
    final streak = session.store.streak;
    final canSkip = session.canSkip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (_, v, child) => FractionalTranslation(translation: Offset(0, v), child: child),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 30 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: AG.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              canSkip ? 'Burn $streak days for 5 more minutes?' : 'No skips left.',
              style: AG.d(28, height: 1.1),
            ),
            const SizedBox(height: 12),
            Text(
              session.isTest
                  ? "Test run, so nothing burns. But imagine it did."
                  : canSkip
                      ? "$skipsLeft emergency skip${skipsLeft == 1 ? '' : 's'} left this month. Your streak goes to zero, and I'll remember."
                      : "You've used them all this month. The only way out is through.",
              style: AG.t(14, color: AG.muted),
            ),
            const SizedBox(height: 18),
            Pill(label: "Fine, I'll do it", onTap: session.closeSkipSheet, padding: const EdgeInsets.all(16), style: AG.d(17)),
            if (canSkip) ...[
              const SizedBox(height: 12),
              Pill(
                label: 'Burn it',
                bg: AG.plum,
                fg: AG.plumInk,
                padding: const EdgeInsets.all(16),
                style: AG.t(15, weight: FontWeight.w700),
                onTap: session.burnSkip,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
