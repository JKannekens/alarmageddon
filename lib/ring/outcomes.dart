import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RingSession>();
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: AG.lime,
      child: Stack(
        children: [
          Positioned(
            left: -40,
            right: -40,
            top: top + 66,
            child: const Marquee(text: "YOU'RE UP", background: AG.bg, foreground: AG.lime, angle: -5, seconds: 10),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        Text("You're alive.", style: AG.d(64, color: AG.bg, height: .95)),
                        const SizedBox(height: 10),
                        Text(
                          'Up in ${s.resultSeconds} seconds. ${successRoast(s.resultSeconds)}'
                          '${s.isTest ? ' (Test run, so it doesn\'t count.)' : ''}',
                          style: AG.t(17, color: AG.bg, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
                  child: Row(
                    children: [
                      PopIn(
                        duration: const Duration(milliseconds: 700),
                        child: Container(
                          width: 110,
                          height: 110,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AG.bg, shape: BoxShape.circle),
                          child: Text('${s.store.streak}', style: AG.d(54, color: AG.lime)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text("day streak.\nDon't get cocky.",
                          style: AG.t(15, color: AG.bg, weight: FontWeight.w600, height: 1.35)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Pill(label: 'Start the day', bg: AG.bg, fg: AG.lime, onTap: s.finish),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkipPenaltyScreen extends StatefulWidget {
  const SkipPenaltyScreen({super.key});
  @override
  State<SkipPenaltyScreen> createState() => _SkipPenaltyScreenState();
}

class _SkipPenaltyScreenState extends State<SkipPenaltyScreen> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  /// ag-crumble: hold, rattle, then drop away blurred.
  Widget _crumble(Widget child) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final v = Curves.easeIn.transform(c.value);
          double dx = 0, dy = 0, rot = 0, scale = 1, op = 1, blur = 0;
          if (v >= .33 && v < .43) {
            final step = ((v - .33) / .02).floor();
            dx = step.isEven ? -6 : 6;
            rot = step.isEven ? -3 : 3;
          } else if (v >= .43) {
            final k = ((v - .43) / .27).clamp(0.0, 1.0);
            dy = 80 * k;
            rot = 12 * k;
            scale = 1 - .3 * k;
            op = 1 - k;
            blur = 4 * k;
          }
          return Opacity(
            opacity: op,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.rotate(
                angle: rot * pi / 180,
                child: Transform.scale(
                  scale: scale,
                  child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: child),
                ),
              ),
            ),
          );
        },
        child: child,
      );

  /// ag-appear: the zero slams in after the old streak is gone.
  Widget _appear(Widget child) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final v = Curves.easeOut.transform(c.value);
          final k = ((v - .62) / .13).clamp(0.0, 1.0);
          return Opacity(opacity: k, child: Transform.scale(scale: 1.6 - .6 * k, child: child));
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RingSession>();
    final big = AG.d(150, height: 1);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency skip used', style: AG.t(13, color: AG.muted)),
                const SizedBox(height: 4),
                Text('You chose violence against yourself.', style: AG.d(32, height: 1.1)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 260,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _crumble(FittedBox(child: Text('${s.lostStreak}', style: big.copyWith(color: AG.lime)))),
                    _appear(Text('0', style: big.copyWith(color: AG.dim))),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Row(
              children: [
                for (var i = 0; i < 12; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: _DroppingBar(controller: c, delay: i * .06 / 3),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              children: [
                Text(
                  s.isTest
                      ? 'Test run. Your streak is fine. This time.'
                      : '${s.store.skipsLeft} skips left this month. I ring again in 5 minutes.',
                  textAlign: TextAlign.center,
                  style: AG.t(12, color: AG.muted),
                ),
                const SizedBox(height: 10),
                Pill(label: "Fine. I'm awake.", onTap: s.finish),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ag-drop: each streak bar tips over and falls away, staggered.
class _DroppingBar extends StatelessWidget {
  const _DroppingBar({required this.controller, required this.delay});
  final AnimationController controller;

  /// Fraction of the controller's run to wait before starting.
  final double delay;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, child) {
          final v = ((controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
          final k = Curves.easeIn.transform(((v - .4) / .35).clamp(0.0, 1.0));
          return Opacity(
            opacity: 1 - k,
            child: Transform.translate(
              offset: Offset(0, 60 * k),
              child: Transform.rotate(angle: 40 * k * pi / 180, child: child),
            ),
          );
        },
        child: Container(height: 26, decoration: BoxDecoration(color: AG.pink, borderRadius: BorderRadius.circular(999))),
      );
}
