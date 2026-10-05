import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Everything the stats screen shows, derived from the wake-up history.
class StatsSummary {
  StatsSummary(List<WakeLog> history, DateTime now) {
    final wins = history.where((l) => !l.skipped).toList();
    fastest = wins.isEmpty ? null : wins.map((l) => l.seconds).reduce((a, b) => a < b ? a : b);
    thingsScanned = wins.where((l) => l.challenge == Challenge.scan).length;

    final counts = <String, int>{};
    for (final w in history.expand((l) => l.failedWords)) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    mostFailedWord = counts.isEmpty ? null : (counts.entries.toList()..sort((a, b) => b.value - a.value)).first.key;

    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    week = List.filled(7, null);
    for (final l in wins) {
      final day = DateTime(l.at.year, l.at.month, l.at.day);
      final i = day.difference(monday).inDays;
      if (i >= 0 && i < 7) week[i] = (week[i] ?? 0) + l.seconds;
    }
  }

  int? fastest;
  int thingsScanned = 0;
  String? mostFailedWord;

  /// Seconds to get up per weekday this week, Monday first. Null = no alarm.
  late final List<int?> week;

  int? get worstIndex {
    int? best;
    for (var i = 0; i < 7; i++) {
      if (week[i] != null && (best == null || week[i]! > week[best]!)) best = i;
    }
    return best;
  }

  String get roast {
    final w = worstIndex;
    if (w == null) return "No mornings logged yet. I'm patient. I'm also an alarm.";
    final s = week[w]!;
    final took = s >= 120 ? '${(s / 60).round()} minutes' : '$s seconds';
    if (s < 60) return '${_dayNames[w]} was your slowest at $took. Suspiciously competent.';
    return "${_dayNames[w]} took you $took. I'm not mad. I'm writing it down.";
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Widget _tile(String value, String label, {Color color = AG.ink}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AG.surface, borderRadius: BorderRadius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AG.d(30, color: color)),
            ),
            Text(label, style: AG.t(12, color: AG.muted)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = StatsSummary(store.history, DateTime.now());
    final maxSecs = s.week.whereType<int>().fold<int>(60, (a, b) => b > a ? b : a);
    final worst = s.worstIndex;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SafeArea(
      bottom: false,
      child: FadeSlideIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
          children: [
            Text('Your record', style: AG.d(20)),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${store.streak}', style: AG.d(120, color: AG.lime, height: .85)),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('mornings without\na skip', style: AG.t(15, color: AG.muted)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Seconds to get up · this week'),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == 6 ? 0 : 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(s.week[i] == null ? '—' : '${s.week[i]}s', style: AG.t(10, color: AG.muted)),
                            const SizedBox(height: 6),
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: s.week[i] == null ? .03 : (s.week[i]! / maxSecs).clamp(.08, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: s.week[i] == null
                                        ? AG.surfaceHi
                                        : i == worst && s.week[i]! >= 120
                                            ? AG.pink
                                            : AG.lime,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(letters[i], style: AG.t(11, weight: FontWeight.w700, color: AG.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
              children: [
                _tile(s.fastest == null ? '—' : '${s.fastest}s', 'Fastest wake-up'),
                _tile('${store.skipsUsedThisMonth}', 'Skips this month', color: AG.pink),
                _tile(s.mostFailedWord ?? '—', 'Word you fail most'),
                _tile('${s.thingsScanned}', 'Things scanned'),
              ],
            ),
            const SizedBox(height: 22),
            RoastBubble(s.roast),
          ],
        ),
      ),
    );
  }
}
