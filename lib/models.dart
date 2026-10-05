enum Difficulty {
  mild('Mild', bpm: 80, shakes: 20),
  spicy('Spicy', bpm: 92, shakes: 30),
  apocalyptic('Apocalyptic', bpm: 112, shakes: 50);

  const Difficulty(this.label, {required this.bpm, required this.shakes});
  final String label;
  final int bpm;
  final int shakes;
}

enum Challenge {
  beat('Sing on beat', 'Carrot, parrot, parrot. One word per beat.', 'Face the beat'),
  scan('Scan a thing', 'I name it, you go find it.', 'Find the thing'),
  math('Math', 'Three sums. Before coffee.', 'Do the math'),
  shake('Shake it', '30 shakes. Arms, wake up.', 'Shake it off');

  const Challenge(this.label, this.blurb, this.cta);
  final String label;
  final String blurb;
  final String cta;
}

enum RoastLevel {
  mild('Mild'),
  savage('Savage'),
  unhinged('Unhinged');

  const RoastLevel(this.label);
  final String label;
}

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

class AlarmSpec {
  AlarmSpec({
    required this.id,
    required this.hour,
    required this.minute,
    required this.days,
    this.enabled = true,
    this.difficulty = Difficulty.spicy,
  });

  final int id;
  final int hour;
  final int minute;

  /// Monday-first repeat flags. All false means "once".
  final List<bool> days;
  final bool enabled;
  final Difficulty difficulty;

  bool get repeats => days.contains(true);
  int get minutesOfDay => hour * 60 + minute;

  AlarmSpec copyWith({int? hour, int? minute, List<bool>? days, bool? enabled, Difficulty? difficulty}) =>
      AlarmSpec(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
        difficulty: difficulty ?? this.difficulty,
      );

  /// The next moment this alarm should ring, strictly after [now].
  DateTime nextFire(DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset, hour, minute);
      if (!day.isAfter(now)) continue;
      if (!repeats || days[day.weekday - 1]) return day;
    }
    // Unreachable: some day within a week always matches.
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days,
        'enabled': enabled,
        'difficulty': difficulty.name,
      };

  factory AlarmSpec.fromJson(Map<String, Object?> j) => AlarmSpec(
        id: j['id'] as int,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        days: (j['days'] as List).cast<bool>(),
        enabled: j['enabled'] as bool? ?? true,
        difficulty: _byName(Difficulty.values, j['difficulty'], Difficulty.spicy),
      );
}

/// One morning's outcome. Feeds the stats screen.
class WakeLog {
  WakeLog({
    required this.at,
    required this.seconds,
    required this.challenge,
    this.skipped = false,
    this.failedWords = const [],
  });

  final DateTime at;
  final int seconds;
  final Challenge challenge;
  final bool skipped;
  final List<String> failedWords;

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'seconds': seconds,
        'challenge': challenge.name,
        'skipped': skipped,
        'failedWords': failedWords,
      };

  factory WakeLog.fromJson(Map<String, Object?> j) => WakeLog(
        at: DateTime.parse(j['at'] as String),
        seconds: j['seconds'] as int,
        challenge: _byName(Challenge.values, j['challenge'], Challenge.math),
        skipped: j['skipped'] as bool? ?? false,
        failedWords: (j['failedWords'] as List?)?.cast<String>() ?? const [],
      );
}

class Prefs {
  Prefs({
    this.roast = RoastLevel.savage,
    Set<Challenge>? pool,
    this.escalate = true,
    this.vibrate = true,
    this.flash = true,
    this.skipQuota = 3,
  }) : pool = pool ?? Challenge.values.toSet();

  final RoastLevel roast;
  final Set<Challenge> pool;
  final bool escalate;
  final bool vibrate;
  final bool flash;
  final int skipQuota;

  Prefs copyWith({
    RoastLevel? roast,
    Set<Challenge>? pool,
    bool? escalate,
    bool? vibrate,
    bool? flash,
    int? skipQuota,
  }) =>
      Prefs(
        roast: roast ?? this.roast,
        pool: pool ?? this.pool,
        escalate: escalate ?? this.escalate,
        vibrate: vibrate ?? this.vibrate,
        flash: flash ?? this.flash,
        skipQuota: skipQuota ?? this.skipQuota,
      );

  Map<String, Object?> toJson() => {
        'roast': roast.name,
        'pool': pool.map((c) => c.name).toList(),
        'escalate': escalate,
        'vibrate': vibrate,
        'flash': flash,
        'skipQuota': skipQuota,
      };

  factory Prefs.fromJson(Map<String, Object?> j) => Prefs(
        roast: _byName(RoastLevel.values, j['roast'], RoastLevel.savage),
        pool: ((j['pool'] as List?)?.map((n) => _byName(Challenge.values, n, Challenge.math)).toSet()),
        escalate: j['escalate'] as bool? ?? true,
        vibrate: j['vibrate'] as bool? ?? true,
        flash: j['flash'] as bool? ?? true,
        skipQuota: j['skipQuota'] as int? ?? 3,
      );
}

String formatClock(int hour, int minute) => '${(hour + 11) % 12 + 1}:${minute.toString().padLeft(2, '0')}';
String amPm(int hour) => hour < 12 ? 'am' : 'pm';

String describeDays(List<bool> days) {
  final s = days.map((d) => d ? '1' : '0').join();
  switch (s) {
    case '1111111':
      return 'Every day';
    case '1111100':
      return 'Weekdays';
    case '0000011':
      return 'Weekends';
    case '0000000':
      return 'Once';
  }
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [for (var i = 0; i < 7; i++) if (days[i]) names[i]].join(', ');
}
