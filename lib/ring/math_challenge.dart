import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../ring_session.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

/// Three sums in a row, no calculator.
class MathChallenge extends StatefulWidget {
  const MathChallenge({super.key});
  @override
  State<MathChallenge> createState() => _MathChallengeState();
}

class _MathChallengeState extends State<MathChallenge> {
  static const needed = 3;

  late final RingSession session = context.read<RingSession>();
  late MathQuestion q = generateMath(session.difficulty);
  int solved = 0;
  String input = '';
  bool wrong = false;
  bool justRight = false;
  int wrongCount = 0;
  String wrongLine = '';

  void _press(String k) {
    session.poke();
    setState(() {
      if (k == 'del') {
        if (input.isNotEmpty) input = input.substring(0, input.length - 1);
        wrong = false;
      } else if (k == 'ok') {
        if (input.isEmpty) return;
        if (int.parse(input) == q.answer) {
          solved++;
          if (solved >= needed) {
            session.win();
            return;
          }
          q = generateMath(session.difficulty);
          input = '';
          wrong = false;
          justRight = true;
        } else {
          input = '';
          wrong = true;
          wrongCount++;
          wrongLine = pick(mathWrong);
          justRight = false;
        }
      } else if (input.length < 5) {
        input += k;
        wrong = false;
      }
    });
  }

  Widget _key(String label, String value, {Color bg = AG.surface, Color fg = AG.ink}) => Pressable(
        pressedScale: .94,
        onTap: () => _press(value),
        semanticLabel: value == 'del' ? 'Delete' : value == 'ok' ? 'Submit' : value,
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: AG.d(24, color: fg)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final question = Text('${q.text} =', style: AG.d(52, height: 1));
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Math · ${(solved + 1).clamp(1, needed)} of $needed', style: AG.t(13, color: AG.muted)),
                Row(
                  children: [
                    for (var i = 0; i < needed; i++)
                      Container(
                        width: 26,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: i < solved ? AG.lime : AG.surfaceHi,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: wrong
                        ? Jitter(key: ValueKey(wrongCount), period: const Duration(milliseconds: 200), repeats: 3, child: question)
                        : question,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    decoration: BoxDecoration(
                      color: AG.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: wrong ? AG.pink : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Text(input, style: AG.d(44, color: AG.lime)),
                        const BlinkCursor(color: AG.lime),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 20,
                    child: Text(
                      wrong
                          ? wrongLine
                          : justRight
                              ? "Correct. Don't celebrate yet."
                              : 'Get three right to stop the noise.',
                      style: AG.t(14, color: wrong ? AG.pink : AG.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.75,
              children: [
                for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) _key(n, n),
                _key('⌫', 'del', bg: AG.surfaceHi, fg: AG.muted),
                _key('0', '0'),
                _key('✓', 'ok', bg: AG.lime, fg: AG.bg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
