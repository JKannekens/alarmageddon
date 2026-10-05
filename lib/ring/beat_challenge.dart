import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';
import 'onset_mic.dart';

/// Sing eight near-rhymes, one per beat, two rounds. Miss a beat and the
/// round restarts with new words.
class BeatChallenge extends StatefulWidget {
  const BeatChallenge({super.key});
  @override
  State<BeatChallenge> createState() => _BeatChallengeState();
}

class _Miss {
  _Miss({required this.beat, required this.word, required this.words, required this.next});
  final int beat;
  final String word;
  final List<String> words;
  final List<String> next;
  final String roast = pick(beatFailRoasts);
}

class _BeatChallengeState extends State<BeatChallenge> with SingleTickerProviderStateMixin {
  static const rounds = 2;

  late final RingSession session = context.read<RingSession>();
  late final int bpm = session.difficulty.bpm;
  late final double beatMs = 60000 / bpm;
  double get windowMs => min(260, beatMs * .42);

  // Challenge clock in ms: the frame ticker's elapsed time, plus a stopwatch
  // for taps and mic onsets that land between frames.
  Duration _frameElapsed = Duration.zero;
  final _sinceFrame = Stopwatch();
  double get _now => (_frameElapsed.inMicroseconds + _sinceFrame.elapsedMicroseconds) / 1000;
  late final Ticker _ticker = createTicker((elapsed) {
    _frameElapsed = elapsed;
    _sinceFrame
      ..reset()
      ..start();
    _tick();
  });

  /// 0..1 progress through the current beat, drives the thump circle.
  final _beatPhase = ValueNotifier<double>(0);

  late List<String> words;
  late List<bool> hits;
  int round = 1;
  int idx = -4;
  bool cleared = false;
  String last = '';
  double _t0 = 0;
  _Miss? miss;
  Timer? _later;

  OnsetMic? _mic;
  bool micOn = false;
  bool micErr = false;

  @override
  void initState() {
    super.initState();
    _startRound(1);
    _ticker.start();
  }

  @override
  void dispose() {
    _later?.cancel();
    _ticker.dispose();
    _beatPhase.dispose();
    _mic?.stop();
    super.dispose();
  }

  void _startRound(int r, [List<String>? next]) {
    setState(() {
      round = r;
      words = next ?? generateBeatWords(session.difficulty);
      hits = List.filled(8, false);
      idx = -4;
      cleared = false;
      last = '';
      miss = null;
      // A four-beat count-in before the first word.
      _t0 = _now + 4 * beatMs;
    });
  }

  void _tick() {
    final now = _now;
    _beatPhase.value = (((now - _t0) % beatMs) + beatMs) % beatMs / beatMs;
    if (miss != null || cleared) return;
    for (var k = 0; k < 8; k++) {
      if (!hits[k] && now > _t0 + k * beatMs + windowMs) return _fail(k);
    }
    // Every window has closed without a miss.
    if (now > _t0 + 7 * beatMs + windowMs) return _roundDone();
    final i = ((now - _t0) / beatMs + .5).floor();
    if (i != idx) setState(() => idx = i);
  }

  void _tap([double? at]) {
    if (miss != null || cleared) return;
    final t = at ?? _now;
    final k = ((t - _t0) / beatMs).round();
    if (k < 0 || k > 7 || hits[k]) return;
    if ((t - (_t0 + k * beatMs)).abs() <= windowMs) {
      session.poke();
      setState(() {
        hits[k] = true;
        last = pick(beatHitCheers);
      });
    }
  }

  void _fail(int k) {
    session.addFailedWord(words[k]);
    final next = generateBeatWords(session.difficulty);
    setState(() => miss = _Miss(beat: k + 1, word: words[k], words: words, next: next));
    _later = Timer(const Duration(milliseconds: 2800), () => _startRound(round, next));
  }

  void _roundDone() {
    setState(() {
      cleared = true;
      idx = 8;
    });
    session.poke();
    _later = Timer(const Duration(milliseconds: 1100), () {
      if (round < rounds) {
        _startRound(round + 1);
      } else {
        session.win();
      }
    });
  }

  Future<void> _toggleMic() async {
    if (micOn) {
      await _mic?.stop();
      _mic = null;
      return setState(() => micOn = false);
    }
    final mic = OnsetMic(clockMs: () => _now, onOnset: (at) => _tap(at));
    final ok = await mic.start();
    if (!mounted) return mic.stop();
    setState(() {
      micOn = ok;
      micErr = !ok;
      _mic = ok ? mic : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = miss;
    return m != null ? _MissView(miss: m) : _play(context);
  }

  Widget _play(BuildContext context) {
    final head = cleared
        ? (round < rounds ? 'Round cleared. Again.' : 'Done. Unbelievable.')
        : idx < 0
            ? 'Get ready…'
            : (last.isEmpty ? 'Sing it.' : last);
    return LayoutBuilder(builder: (context, box) {
      final cx = box.maxWidth / 2, cy = box.maxHeight * .45;
      return Stack(
        children: [
          Positioned(
            left: cx - 160,
            top: cy - 160,
            child: ValueListenableBuilder<double>(
              valueListenable: _beatPhase,
              builder: (_, p, child) {
                final e = Curves.easeOut.transform(p);
                return Opacity(
                  opacity: 1 - .6 * e,
                  child: Transform.scale(scale: 1.15 - .3 * e, child: child),
                );
              },
              child: Dot(size: 320, color: AG.limeTint(.14)),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Round $round / $rounds · $bpm BPM', style: AG.t(13, color: AG.muted)),
                      Pill(
                        label: micOn ? '● Mic on' : 'Use mic',
                        expand: false,
                        bg: micOn ? AG.pink : AG.surface,
                        fg: micOn ? AG.bg : AG.muted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        style: AG.t(12, weight: FontWeight.w700),
                        onTap: _toggleMic,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(head, style: AG.d(22))),
                      if (idx < 0 && !cleared)
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AG.pink, shape: BoxShape.circle),
                          child: Text('${-idx}', style: AG.d(30, color: AG.bg)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < 8; i++)
                            FractionallySizedBox(widthFactor: .5, child: _word(i)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 8; i++)
                            Expanded(
                              child: Container(
                                height: 10,
                                margin: EdgeInsets.only(left: i == 0 ? 0 : 3, right: i == 7 ? 0 : 3),
                                decoration: BoxDecoration(
                                  color: hits[i] ? AG.pink : (i == idx ? AG.lime : AG.surfaceHi),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Pressable(
                            pressedScale: .9,
                            onTap: _tap,
                            semanticLabel: 'Sing',
                            child: Container(
                              width: 96,
                              height: 96,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AG.lime,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AG.limeTint(.25), spreadRadius: 6)],
                              ),
                              child: Text('SING', style: AG.d(20, color: AG.bg)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 36, child: _Eq()),
                                const SizedBox(height: 8),
                                Text(
                                  micOn
                                      ? 'Mic on: just sing each word on the beat.'
                                      : micErr
                                          ? 'No mic access. Tap SING on every beat.'
                                          : 'Tap SING as you say each word, on the beat.',
                                  style: AG.t(12, color: AG.muted, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _word(int i) {
    final current = i == idx && !cleared;
    return AnimatedScale(
      scale: current ? 1.1 : 1,
      alignment: Alignment.centerLeft,
      duration: const Duration(milliseconds: 80),
      child: AnimatedRotation(
        turns: current ? -4 / 360 : 0,
        alignment: Alignment.centerLeft,
        duration: const Duration(milliseconds: 80),
        child: Text(
          words[i],
          style: AG.d(34, height: 1.15, color: hits[i] ? AG.pink : (current ? AG.lime : AG.dim)),
        ),
      ),
    );
  }
}

/// Decorative level meter.
class _Eq extends StatefulWidget {
  const _Eq();
  @override
  State<_Eq> createState() => _EqState();
}

class _EqState extends State<_Eq> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final t = c.value * 10;
          return Row(
            children: [
              for (var i = 0; i < 18; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: FractionallySizedBox(
                      heightFactor: () {
                        final period = .35 + (i * 37 % 10) / 22;
                        final x = ((t - i * .06) / period) % 2;
                        final tri = x < 1 ? x : 2 - x;
                        return .2 + .8 * Curves.easeInOut.transform(tri);
                      }(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: i % 3 == 0 ? AG.lime : AG.pink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _MissView extends StatelessWidget {
  const _MissView({required this.miss});
  final _Miss miss;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 2800),
                builder: (_, v, _) =>
                    Container(color: AG.pink.withValues(alpha: v < .12 ? .9 * (1 - v / .12) : 0)),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
                  child: Jitter(
                    period: const Duration(milliseconds: 250),
                    repeats: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BEAT ${miss.beat} OF 8', style: AG.label.copyWith(fontSize: 13, color: AG.pink)),
                        Text('Missed.', style: AG.d(84, color: AG.lime, height: .95)),
                        const SizedBox(height: 10),
                        Text('It was "${miss.word}". ${miss.roast}', style: AG.t(17, height: 1.35)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      for (final (i, w) in miss.words.indexed)
                        Positioned(
                          left: 24.0 + (i % 2) * 150,
                          top: 10.0 + (i ~/ 2) * 38,
                          child: _FallingWord(word: w, delayMs: i * 100, spinDeg: (i.isOdd ? 1 : -1) * (20 + i * 9.0)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('New words incoming', textAlign: TextAlign.center, style: AG.t(12, color: AG.muted)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: AG.plum, borderRadius: BorderRadius.circular(999)),
                        child: Text('${miss.next.take(3).join(' · ')}…',
                            textAlign: TextAlign.center, style: AG.d(16, color: AG.plumInk)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _FallingWord extends StatefulWidget {
  const _FallingWord({required this.word, required this.delayMs, required this.spinDeg});
  final String word;
  final int delayMs;
  final double spinDeg;
  @override
  State<_FallingWord> createState() => _FallingWordState();
}

class _FallingWordState extends State<_FallingWord> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  static const _curve = Cubic(.5, 0, .9, .5);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final v = _curve.transform(c.value);
          // Hold, fall and spin, then fade out at the bottom.
          final fall = v < .15 ? 0.0 : ((v - .15) / .65).clamp(0.0, 1.0);
          final fade = v < .8 ? 1.0 : 1 - (v - .8) / .2;
          return Opacity(
            opacity: fade.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, 340 * fall),
              child: Transform.rotate(angle: widget.spinDeg * fall * pi / 180, child: child),
            ),
          );
        },
        child: Text(widget.word, style: AG.d(30, color: AG.dim)),
      );
}
