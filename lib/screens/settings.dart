import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';
import 'onboarding.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool poolWarn = false;

  void _togglePool(AppStore store, Challenge c) {
    final pool = {...store.prefs.pool};
    if (pool.contains(c) && pool.length <= 2) return setState(() => poolWarn = true);
    pool.contains(c) ? pool.remove(c) : pool.add(c);
    setState(() => poolWarn = false);
    store.updatePrefs(store.prefs.copyWith(pool: pool));
  }

  void _replayOnboarding() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (ctx) => OnboardingScreen(onDone: () => Navigator.of(ctx).pop()),
      ));

  Widget _round(String glyph, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AG.surface, shape: BoxShape.circle),
            child: Text(glyph, style: AG.t(16, weight: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.prefs;
    final toggles = [
      ('Escalating volume', 'Gets louder every 30 seconds.', p.escalate, () => p.copyWith(escalate: !p.escalate)),
      ('Vibrate like crazy', 'Phone does a little dance.', p.vibrate, () => p.copyWith(vibrate: !p.vibrate)),
      ('Screen flash', 'Strobe the room when ringing.', p.flash, () => p.copyWith(flash: !p.flash)),
    ];

    return SafeArea(
      bottom: false,
      child: FadeSlideIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
          children: [
            Text('Settings', style: AG.d(20)),
            const SizedBox(height: 22),
            const SectionLabel('Roast level'),
            const SizedBox(height: 10),
            Segmented<RoastLevel>(
              options: RoastLevel.values,
              selected: p.roast,
              labelOf: (r) => r.label,
              onPick: (r) => store.updatePrefs(p.copyWith(roast: r)),
            ),
            const SizedBox(height: 10),
            RoastBubble('"${roasts[p.roast]!.first}"', bg: AG.surface, fg: AG.ink),
            const SizedBox(height: 22),
            const SectionLabel('Challenge pool'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, c) in Challenge.values.indexed)
                  GestureDetector(
                    onTap: () => _togglePool(store, c),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 150),
                      turns: p.pool.contains(c) ? (i.isOdd ? 1.5 : -1.5) / 360 : 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.pool.contains(c) ? (i.isOdd ? AG.pink : AG.lime) : AG.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          c.label,
                          style: AG.t(14, weight: FontWeight.w700, color: p.pool.contains(c) ? AG.bg : AG.muted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              poolWarn
                  ? "Nice try. At least two stay on, or it isn't random."
                  : "One gets rolled each morning. Turn off what you can't do (singing next to a sleeping partner, say).",
              style: AG.t(12, color: poolWarn ? AG.pink : AG.muted),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Behaviour'),
            for (final (label, desc, on, next) in toggles)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: AG.t(15, weight: FontWeight.w600)),
                          Text(desc, style: AG.t(12, color: AG.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AgToggle(on: on, label: label, onTap: () => store.updatePrefs(next())),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency skips', style: AG.t(15, weight: FontWeight.w600)),
                        Text('Per month. Each one resets your streak.', style: AG.t(12, color: AG.muted)),
                      ],
                    ),
                  ),
                  _round('−', () => store.setSkipQuota(max(0, p.skipQuota - 1)), 'Fewer skips'),
                  SizedBox(
                    width: 28,
                    child: Text('${p.skipQuota}', textAlign: TextAlign.center, style: AG.d(20)),
                  ),
                  _round('+', () => store.setSkipQuota(p.skipQuota + 1), 'More skips'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Pill(
              label: 'Replay onboarding',
              bg: AG.surface,
              fg: AG.ink,
              padding: const EdgeInsets.all(14),
              style: AG.t(14, weight: FontWeight.w700),
              onTap: _replayOnboarding,
            ),
          ],
        ),
      ),
    );
  }
}
