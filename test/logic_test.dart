import 'package:alarmageddon/content.dart';
import 'package:alarmageddon/models.dart';
import 'package:alarmageddon/screens/stats.dart';
import 'package:flutter_test/flutter_test.dart';

AlarmSpec alarm(int h, int m, String days) =>
    AlarmSpec(id: 1, hour: h, minute: m, days: days.split('').map((c) => c == '1').toList());

void main() {
  group('nextFire', () {
    // 2026-10-05 is a Monday.
    final monMorning = DateTime(2026, 10, 5, 6, 0);

    test('one-off later today', () {
      expect(alarm(6, 30, '0000000').nextFire(monMorning), DateTime(2026, 10, 5, 6, 30));
    });

    test('one-off already passed rolls to tomorrow', () {
      expect(alarm(5, 0, '0000000').nextFire(monMorning), DateTime(2026, 10, 6, 5, 0));
    });

    test('exactly now is not "next"', () {
      expect(alarm(6, 0, '0000000').nextFire(monMorning), DateTime(2026, 10, 6, 6, 0));
    });

    test('weekdays alarm on Friday evening jumps to Monday', () {
      final friNight = DateTime(2026, 10, 9, 22, 0);
      expect(alarm(6, 30, '1111100').nextFire(friNight), DateTime(2026, 10, 12, 6, 30));
    });

    test('weekly alarm whose time passed today waits a full week', () {
      final monNoon = DateTime(2026, 10, 5, 12, 0);
      expect(alarm(6, 30, '1000000').nextFire(monNoon), DateTime(2026, 10, 12, 6, 30));
    });

    test('Sunday-only alarm', () {
      expect(alarm(10, 15, '0000001').nextFire(monMorning), DateTime(2026, 10, 11, 10, 15));
    });
  });

  test('describeDays', () {
    expect(describeDays(alarm(0, 0, '1111111').days), 'Every day');
    expect(describeDays(alarm(0, 0, '1111100').days), 'Weekdays');
    expect(describeDays(alarm(0, 0, '0000011').days), 'Weekends');
    expect(describeDays(alarm(0, 0, '0000000').days), 'Once');
    expect(describeDays(alarm(0, 0, '1010000').days), 'Mon, Wed');
  });

  test('formatClock is 12-hour', () {
    expect(formatClock(0, 5), '12:05');
    expect(formatClock(13, 0), '1:00');
    expect(amPm(11), 'am');
    expect(amPm(12), 'pm');
  });

  test('beat words mix both words of one pair and are never sorted', () {
    for (var i = 0; i < 200; i++) {
      final w = generateBeatWords(Difficulty.spicy);
      expect(w, hasLength(8));
      expect(w.toSet(), hasLength(2));
      expect(rhymePairs.any((p) => p.toSet().containsAll(w.toSet())), isTrue);
      final sorted = [...w]..sort();
      expect(w.join(), isNot(sorted.join()));
    }
  });

  test('math answers match the question', () {
    for (final d in Difficulty.values) {
      final q = generateMath(d);
      final m = RegExp(r'(\d+) × (\d+) \+ (\d+)').firstMatch(q.text)!;
      expect(int.parse(m[1]!) * int.parse(m[2]!) + int.parse(m[3]!), q.answer);
    }
  });

  test('json round trips', () {
    final a = alarm(6, 30, '1111100').copyWith(difficulty: Difficulty.apocalyptic, enabled: false);
    final b = AlarmSpec.fromJson(a.toJson());
    expect([b.hour, b.minute, b.days, b.enabled, b.difficulty], [6, 30, a.days, false, Difficulty.apocalyptic]);

    final p = Prefs(roast: RoastLevel.unhinged, pool: {Challenge.math, Challenge.shake}, skipQuota: 5);
    final q = Prefs.fromJson(p.toJson());
    expect([q.roast, q.pool, q.skipQuota], [RoastLevel.unhinged, {Challenge.math, Challenge.shake}, 5]);
  });

  test('stats summary', () {
    final now = DateTime(2026, 10, 8, 9); // Thursday
    final history = [
      WakeLog(at: DateTime(2026, 10, 5, 6, 31), seconds: 62, challenge: Challenge.beat, failedWords: ['Parrot']),
      WakeLog(at: DateTime(2026, 10, 6, 6, 31), seconds: 48, challenge: Challenge.scan),
      WakeLog(at: DateTime(2026, 10, 7, 6, 33), seconds: 180, challenge: Challenge.beat, failedWords: ['Parrot', 'Cake']),
      WakeLog(at: DateTime(2026, 10, 8, 6, 30), seconds: 0, challenge: Challenge.math, skipped: true),
      WakeLog(at: DateTime(2026, 9, 28, 6, 30), seconds: 30, challenge: Challenge.scan), // last week
    ];
    final s = StatsSummary(history, now);
    expect(s.week, [62, 48, 180, null, null, null, null]);
    expect(s.fastest, 30);
    expect(s.thingsScanned, 2);
    expect(s.mostFailedWord, 'Parrot');
    expect(s.worstIndex, 2);
    expect(s.roast, contains('Wednesday took you 3 minutes'));
  });
}
