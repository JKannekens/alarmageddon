import 'package:flutter/material.dart';

import '../models.dart';
import '../permissions.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  bool asking = false;

  Future<void> _next() async {
    if (step < 2) return setState(() => step++);
    setState(() => asking = true);
    await requestEverything();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: FadeSlideIn(
                      duration: const Duration(milliseconds: 400),
                      child: switch (step) { 0 => const _Intro(), 1 => const _Poison(), _ => const _Permissions() },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == step ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == step ? AG.lime : AG.surfaceHi,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Pill(
                      label: step == 2 ? 'Grant everything' : 'Next',
                      expand: false,
                      onTap: asking ? null : _next,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                      style: AG.d(17),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final cx = box.maxWidth / 2;
          const cy = 190.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: cx - 210,
                top: cy - 210,
                child: Pulse(child: Dot(size: 420, color: AG.limeTint(.18))),
              ),
              Positioned(
                left: cx - 130,
                top: cy - 130,
                child: const Pulse(period: Duration(milliseconds: 650), child: Dot(size: 260, color: AG.lime)),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: cy - 40,
                child: Center(
                  child: Jitter(
                    child: Text(
                      'Zzz.',
                      style: AG.d(64, color: AG.bg).copyWith(
                        shadows: const [Shadow(color: AG.pink, offset: Offset(3, 0))],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your snooze button is dead.', style: AG.d(40, height: 1.02)),
                    const SizedBox(height: 12),
                    Text(
                      "I don't stop ringing until you prove you're awake. Sing, scan, solve or shake. Your choice. Sort of.",
                      style: AG.t(15, color: AG.muted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _Poison extends StatelessWidget {
  const _Poison();

  Widget _card(Challenge c, Color bg, Color fg, Color sub, double deg) => Transform.rotate(
        angle: deg * 3.14159 / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.label, style: AG.d(20, color: fg)),
              const SizedBox(height: 6),
              Text(c.blurb, style: AG.t(12, color: sub, height: 1.35)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("I'll pick your poison.", style: AG.d(36, height: 1.05)),
            const SizedBox(height: 14),
            Text('Every morning I roll one of these at random. You find out when it rings.',
                style: AG.t(14, color: AG.muted)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _card(Challenge.beat, AG.lime, AG.bg, AG.bg, -2)),
                const SizedBox(width: 10),
                Expanded(child: _card(Challenge.scan, AG.pink, AG.bg, AG.bg, 2)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _card(Challenge.math, AG.surface, AG.ink, AG.muted, 1.5)),
                const SizedBox(width: 10),
                Expanded(child: _card(Challenge.shake, AG.surface, AG.ink, AG.muted, -1.5)),
              ],
            ),
          ],
        ),
      );
}

class _Permissions extends StatelessWidget {
  const _Permissions();

  static const _rows = [
    (AG.lime, 'Microphone', 'To hear you sing. Badly is fine.'),
    (AG.pink, 'Camera', 'To see the cup. Not your face.'),
    (AG.ink, 'Motion', 'To count shakes.'),
    (AG.dim, 'Notifications', 'Obviously.'),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Let me in.', style: AG.d(36, height: 1.05)),
            const SizedBox(height: 14),
            Text("I need these to know you're actually up.", style: AG.t(14, color: AG.muted)),
            const SizedBox(height: 20),
            for (final (color, title, desc) in _rows)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(color: AG.surface, borderRadius: BorderRadius.circular(28)),
                child: Row(
                  children: [
                    Dot(size: 40, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AG.t(15, weight: FontWeight.w700)),
                          Text(desc, style: AG.t(12, color: AG.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
