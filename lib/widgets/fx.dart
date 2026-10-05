import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Repeating animation driver shared by the effects below.
abstract class _LoopState<T extends StatefulWidget> extends State<T> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  Timer? _start;

  Duration get period;
  Duration get delay => Duration.zero;

  /// Null loops forever.
  int? get repeats => null;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: period);
    _start = Timer(delay, () {
      if (!mounted) return;
      final n = repeats;
      if (n == null) {
        c.repeat();
      } else {
        _runTimes(n);
      }
    });
  }

  Future<void> _runTimes(int n) async {
    for (var i = 0; i < n && mounted; i++) {
      await c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    c.dispose();
    super.dispose();
  }
}

/// ag-pulse: breathe between 1 and 1.06.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.period = const Duration(milliseconds: 1300), this.delay = Duration.zero});
  final Widget child;
  final Duration period;
  final Duration delay;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends _LoopState<Pulse> {
  @override
  Duration get period => widget.period;
  @override
  Duration get delay => widget.delay;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(c.value < .5 ? c.value * 2 : (1 - c.value) * 2);
          return Transform.scale(scale: 1 + .06 * t, child: child);
        },
        child: widget.child,
      );
}

/// ag-ripple: an expanding, fading ring.
class Ripple extends StatefulWidget {
  const Ripple({super.key, required this.size, required this.color, this.delay = Duration.zero});
  final double size;
  final Color color;
  final Duration delay;
  @override
  State<Ripple> createState() => _RippleState();
}

class _RippleState extends _LoopState<Ripple> {
  @override
  Duration get period => const Duration(milliseconds: 1960);
  @override
  Duration get delay => widget.delay;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final t = Curves.easeOut.transform(c.value);
          return Opacity(
            opacity: c.isAnimating || c.value > 0 ? .9 * (1 - t) : 0,
            child: Transform.scale(
              scale: 1 + 1.1 * t,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 3)),
              ),
            ),
          );
        },
      );
}

/// ag-shake with steps(2): flips between two offsets every half period.
class Jitter extends StatefulWidget {
  const Jitter({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 180),
    this.repeats,
    this.amount = 2,
  });
  final Widget child;
  final Duration period;
  final int? repeats;
  final double amount;
  @override
  State<Jitter> createState() => _JitterState();
}

class _JitterState extends _LoopState<Jitter> {
  @override
  Duration get period => widget.period;
  @override
  int? get repeats => widget.repeats;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          if (!c.isAnimating) return child!;
          final a = widget.amount;
          final first = c.value < .5;
          return Transform.translate(
            offset: first ? Offset(-a, a / 2) : Offset(a, -a / 2),
            child: Transform.rotate(angle: (first ? -1 : 1) * pi / 180, child: child),
          );
        },
        child: widget.child,
      );
}

/// ag-pop: overshooting scale-in with a twist.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.duration = const Duration(milliseconds: 450)});
  final Widget child;
  final Duration duration;
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final v = Curves.easeOut.transform(c.value);
          final double scale, deg, op;
          if (v < .6) {
            final k = v / .6;
            scale = .4 + .75 * k;
            deg = -12 + 16 * k;
            op = k;
          } else {
            final k = (v - .6) / .4;
            scale = 1.15 - .15 * k;
            deg = 4 - 4 * k;
            op = 1;
          }
          return Opacity(
            opacity: op.clamp(0, 1),
            child: Transform.rotate(angle: deg * pi / 180, child: Transform.scale(scale: scale, child: child)),
          );
        },
        child: widget.child,
      );
}

/// ag-wobble: a gentle rock to say "press me".
class Wobble extends StatefulWidget {
  const Wobble({super.key, required this.child});
  final Widget child;
  @override
  State<Wobble> createState() => _WobbleState();
}

class _WobbleState extends _LoopState<Wobble> {
  @override
  Duration get period => const Duration(milliseconds: 1300);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final s = sin(c.value * 2 * pi);
          return Transform.rotate(
            angle: -2 * s * pi / 180,
            child: Transform.scale(scale: 1 + .03 * s.abs(), child: child),
          );
        },
        child: widget.child,
      );
}

/// ag-in: fade up into place.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.duration = const Duration(milliseconds: 300)});
  final Widget child;
  final Duration duration;
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final v = Curves.easeOut.transform(c.value);
          return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child));
        },
        child: widget.child,
      );
}

/// A rotated ticker tape of repeated text (GET UP · GET UP · …).
class Marquee extends StatefulWidget {
  const Marquee({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.seconds = 9,
    this.reverse = false,
    this.angle = 0,
  });
  final String text;
  final Color background;
  final Color foreground;
  final int seconds;
  final bool reverse;

  /// Degrees.
  final double angle;
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends _LoopState<Marquee> {
  @override
  Duration get period => Duration(seconds: widget.seconds);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Caprasimo', fontSize: 20, color: widget.foreground, height: 1.2);
    final unit = '${widget.text} · ' * 8;
    final w = (TextPainter(text: TextSpan(text: unit, style: style), textDirection: TextDirection.ltr)..layout()).width;
    return Transform.rotate(
      angle: widget.angle * pi / 180,
      child: Container(
        color: widget.background,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 24,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, _) {
                final v = widget.reverse ? 1 - c.value : c.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Two copies side by side; sliding one copy's width loops seamlessly.
                    Positioned(
                      left: -w * v,
                      top: 0,
                      child: Text(unit + unit, style: style, maxLines: 1, softWrap: false),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Blinking text cursor.
class BlinkCursor extends StatefulWidget {
  const BlinkCursor({super.key, required this.color, this.height = 40});
  final Color color;
  final double height;
  @override
  State<BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends _LoopState<BlinkCursor> {
  @override
  Duration get period => const Duration(seconds: 1);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) => Opacity(
          opacity: c.value < .5 ? 1 : 0,
          child: Container(width: 3, height: widget.height, margin: const EdgeInsets.only(left: 4), color: widget.color),
        ),
      );
}

/// Solid circle helper.
class Dot extends StatelessWidget {
  const Dot({super.key, required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
