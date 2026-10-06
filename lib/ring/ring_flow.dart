import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../ring_session.dart';
import '../theme.dart';
import 'beat_challenge.dart';
import 'math_challenge.dart';
import 'outcomes.dart';
import 'ring_screen.dart';
import 'scan_challenge.dart';
import 'shake_challenge.dart';

/// Full-screen flow shown while an alarm is going off. Cannot be backed out of.
class RingFlow extends StatelessWidget {
  const RingFlow({super.key, required this.session});
  final RingSession session;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: session,
        child: Scaffold(
          backgroundColor: AG.bg,
          body: Selector<RingSession, (RingPhase, bool, Challenge)>(
            selector: (_, s) => (s.phase, s.nagging, s.rolled),
            builder: (_, state, _) {
              final (phase, nagging, rolled) = state;
              final Widget body = switch (phase) {
                RingPhase.ringing => const RingScreen(),
                RingPhase.challenge => switch (rolled) {
                    Challenge.beat => const BeatChallenge(),
                    Challenge.scan => const ScanChallenge(),
                    Challenge.math => const MathChallenge(),
                    Challenge.shake => const ShakeChallenge(),
                  },
                RingPhase.success => const SuccessScreen(),
                RingPhase.skipped => const SkipPenaltyScreen(),
              };
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(key: ValueKey(phase), child: body),
                    ),
                  ),
                  if (nagging && phase == RingPhase.challenge) const _NagBanner(),
                ],
              );
            },
          ),
        ),
      );
}

/// Shown when the watchdog re-rings because the user stalled.
class _NagBanner extends StatelessWidget {
  const _NagBanner();

  @override
  Widget build(BuildContext context) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.paddingOf(context).top + 8,
        child: GestureDetector(
          onTap: context.read<RingSession>().poke,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(color: AG.pink, borderRadius: BorderRadius.circular(999)),
            child: Text(
              'Too slow. I came back. Keep going.',
              textAlign: TextAlign.center,
              style: AG.t(14, weight: FontWeight.w700, color: AG.bg),
            ),
          ),
        ),
      );
}
