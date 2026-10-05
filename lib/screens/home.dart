import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';
import 'edit_alarm.dart';
import 'shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Keeps "Doom arrives in…" current.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _edit(AlarmSpec? a) {
    final tab = context.read<ShellTab>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditAlarmScreen(existing: a, onOpenPool: () => tab.value = ShellTab.settings),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final next = store.nextAlarm(now);
    final others = store.byTime.where((a) => a != next).toList();

    return SafeArea(
      bottom: false,
      child: FadeSlideIn(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Alarmageddon', style: AG.d(20)),
                      Pill(
                        label: 'Test the doom',
                        expand: false,
                        bg: AG.plum,
                        fg: AG.plumInk,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        style: AG.t(12, weight: FontWeight.w700),
                        onTap: store.testRing,
                      ),
                    ],
                  ),
                ),
                if (next != null)
                  _NextAlarm(alarm: next, now: now, streak: store.streak, onTap: () => _edit(next))
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No alarms on.', style: AG.d(40, height: 1.05)),
                        const SizedBox(height: 8),
                        Text("Sleeping in? Bold. I respect it. I don't like it.", style: AG.t(14, color: AG.muted)),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 200),
                    children: [
                      if (others.isNotEmpty) ...[
                        const SectionLabel(
                          'Also scheduled',
                        ),
                        const SizedBox(height: 20),
                      ],
                      for (final a in others)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _AlarmRow(
                            alarm: a,
                            onTap: () => _edit(a),
                            onToggle: () => store.toggleAlarm(a.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 24,
              bottom: 110,
              child: Pressable(
                pressedScale: .92,
                semanticLabel: 'New alarm',
                onTap: () => _edit(null),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AG.lime,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AG.lime.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Text('+', style: AG.d(32, color: AG.bg, height: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _countdown(Duration d) {
  final m = d.inMinutes + (d.inSeconds % 60 > 0 ? 1 : 0);
  return '${m ~/ 60}h ${m % 60}m';
}

class _NextAlarm extends StatelessWidget {
  const _NextAlarm({required this.alarm, required this.now, required this.streak, required this.onTap});
  final AlarmSpec alarm;
  final DateTime now;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doom arrives in ${_countdown(alarm.nextFire(now).difference(now))}',
                  style: AG.t(13, color: AG.muted)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatClock(alarm.hour, alarm.minute), style: AG.d(108, color: AG.lime, height: .9)),
                    const SizedBox(width: 8),
                    Text(amPm(alarm.hour), style: AG.d(22, color: AG.lime)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tag('Surprise challenge', bg: AG.limeTint(.22)),
                  Tag(describeDays(alarm.days), bg: AG.surface, fg: AG.muted),
                  Tag('$streak-day streak', bg: AG.plum, fg: AG.plumInk),
                ],
              ),
            ],
          ),
        ),
      );
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow({required this.alarm, required this.onTap, required this.onToggle});
  final AlarmSpec alarm;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: alarm.enabled ? 1 : .4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: formatClock(alarm.hour, alarm.minute), style: AG.d(30, height: 1.1)),
                        TextSpan(text: ' ${amPm(alarm.hour)}', style: AG.d(14)),
                      ]),
                    ),
                    Text('${describeDays(alarm.days)} · Surprise challenge', style: AG.t(12, color: AG.muted)),
                  ],
                ),
              ),
            ),
            AgToggle(on: alarm.enabled, onTap: onToggle, label: 'Toggle alarm'),
          ],
        ),
      );
}
