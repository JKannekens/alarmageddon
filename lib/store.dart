import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'models.dart';
import 'ring_session.dart';
import 'scheduler.dart';

/// App-wide state: alarms, settings, streak and wake-up history, plus the
/// live ring session when an alarm is going off.
class AppStore extends ChangeNotifier {
  AppStore._(this._sp, this.scheduler);

  final SharedPreferences _sp;
  final Scheduler scheduler;

  bool onboarded = false;
  List<AlarmSpec> alarms = [];
  Prefs prefs = Prefs();
  int streak = 0;
  List<WakeLog> history = [];

  /// The alarm a pending emergency-skip re-ring belongs to.
  int? _snoozeOf;

  /// The alarm whose session is in progress, kept so a watchdog re-ring after
  /// an app restart still knows which difficulty to use.
  int? _activeAlarm;

  RingSession? session;
  StreamSubscription<Set<int>>? _ringSub;

  static Future<AppStore> load(Scheduler scheduler) async {
    final store = AppStore._(await SharedPreferences.getInstance(), scheduler);
    store._read();
    return store;
  }

  void _read() {
    onboarded = _sp.getBool('onboarded') ?? false;
    streak = _sp.getInt('streak') ?? 0;
    _snoozeOf = _sp.getInt('snoozeOf');
    _activeAlarm = _sp.getInt('activeAlarm');
    final a = _sp.getString('alarms');
    if (a != null) {
      alarms = (jsonDecode(a) as List).map((e) => AlarmSpec.fromJson(e as Map<String, Object?>)).toList();
    }
    final p = _sp.getString('prefs');
    if (p != null) prefs = Prefs.fromJson(jsonDecode(p) as Map<String, Object?>);
    final h = _sp.getString('history');
    if (h != null) {
      history = (jsonDecode(h) as List).map((e) => WakeLog.fromJson(e as Map<String, Object?>)).toList();
    }
  }

  void _save() {
    _sp.setBool('onboarded', onboarded);
    _sp.setInt('streak', streak);
    _sp.setString('alarms', jsonEncode(alarms.map((a) => a.toJson()).toList()));
    _sp.setString('prefs', jsonEncode(prefs.toJson()));
    _sp.setString('history', jsonEncode(history.map((l) => l.toJson()).toList()));
    _snoozeOf == null ? _sp.remove('snoozeOf') : _sp.setInt('snoozeOf', _snoozeOf!);
    _activeAlarm == null ? _sp.remove('activeAlarm') : _sp.setInt('activeAlarm', _activeAlarm!);
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  /// Arms every alarm and starts listening for rings. Call once after load.
  Future<void> start() async {
    await syncSchedule();
    _ringSub = scheduler.ringing.listen(_onRinging);
  }

  @override
  void dispose() {
    _ringSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- alarms

  List<AlarmSpec> get byTime => [...alarms]..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

  /// The enabled alarm that fires soonest.
  AlarmSpec? nextAlarm(DateTime now) {
    final on = alarms.where((a) => a.enabled).toList();
    if (on.isEmpty) return null;
    on.sort((a, b) => a.nextFire(now).compareTo(b.nextFire(now)));
    return on.first;
  }

  AlarmSpec? byId(int? id) {
    for (final a in alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  int newAlarmId() {
    final used = alarms.map((a) => a.id).toSet();
    var id = 1;
    while (used.contains(id)) {
      id++;
    }
    return id;
  }

  void saveAlarm(AlarmSpec spec) {
    final i = alarms.indexWhere((a) => a.id == spec.id);
    if (i >= 0) {
      alarms[i] = spec.copyWith(enabled: true);
    } else {
      alarms.add(spec.copyWith(enabled: true));
    }
    _changed();
    syncSchedule();
  }

  void deleteAlarm(int id) {
    alarms.removeWhere((a) => a.id == id);
    _changed();
    scheduler.disarm(id);
  }

  void toggleAlarm(int id) {
    final i = alarms.indexWhere((a) => a.id == id);
    if (i < 0) return;
    alarms[i] = alarms[i].copyWith(enabled: !alarms[i].enabled);
    _changed();
    syncSchedule();
  }

  /// Arms the next occurrence of every enabled alarm, disarms the rest.
  /// Skips anything currently ringing: re-arming would silence it.
  Future<void> syncSchedule() async {
    final now = DateTime.now();
    final body = roasts[prefs.roast]!.first;
    for (final a in alarms) {
      if (await scheduler.isRinging(a.id)) continue;
      if (a.enabled) {
        await scheduler.arm(a.id, a.nextFire(now), prefs, body: body);
      } else {
        await scheduler.disarm(a.id);
      }
    }
  }

  // ---------------------------------------------------------------- settings

  void onboardingDone() {
    onboarded = true;
    _changed();
  }

  void updatePrefs(Prefs next) {
    final rearm = next.vibrate != prefs.vibrate || next.escalate != prefs.escalate || next.roast != prefs.roast;
    prefs = next;
    _changed();
    if (rearm) syncSchedule();
  }

  void setSkipQuota(int quota) => updatePrefs(prefs.copyWith(skipQuota: quota.clamp(0, 9)));

  // ---------------------------------------------------------------- stats

  bool _thisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  int get skipsUsedThisMonth => history.where((l) => l.skipped && _thisMonth(l.at)).length;
  int get skipsLeft => (prefs.skipQuota - skipsUsedThisMonth).clamp(0, 99);

  // ---------------------------------------------------------------- ringing

  void _onRinging(Set<int> ids) {
    if (ids.isEmpty) return;
    final current = session;
    if (current != null) {
      if (ids.contains(Scheduler.watchdogId)) current.nag();
      return;
    }
    final id = ids.first;
    final AlarmSpec? alarm = switch (id) {
      Scheduler.snoozeId => byId(_snoozeOf),
      Scheduler.watchdogId => byId(_activeAlarm),
      Scheduler.testId => nextAlarm(DateTime.now()),
      _ => byId(id),
    };
    _begin(
      firingId: id,
      alarm: alarm ?? AlarmSpec(id: 0, hour: DateTime.now().hour, minute: DateTime.now().minute, days: List.filled(7, false)),
      isTest: id == Scheduler.testId,
    );
  }

  /// "Test the doom": rings for real a few seconds from now, or immediately
  /// on platforms without the alarm plugin.
  Future<void> testRing() async {
    if (!scheduler.supported) {
      final a = nextAlarm(DateTime.now()) ??
          AlarmSpec(id: 0, hour: DateTime.now().hour, minute: DateTime.now().minute, days: List.filled(7, false));
      _begin(firingId: Scheduler.testId, alarm: a, isTest: true);
      return;
    }
    await scheduler.arm(Scheduler.testId, DateTime.now().add(const Duration(seconds: 3)), prefs,
        body: 'Test run. Still annoying.');
  }

  void _begin({required int firingId, required AlarmSpec alarm, required bool isTest}) {
    final pool = prefs.pool.isEmpty ? Challenge.values : prefs.pool.toList();
    session = RingSession(
      store: this,
      firingId: firingId,
      alarm: alarm,
      isTest: isTest,
      pool: pool,
      roastLine: pick(roasts[prefs.roast]!),
      flash: prefs.flash,
    );
    if (!isTest) _activeAlarm = alarm.id;
    _changed();
  }

  /// Silences the ring while a challenge is underway. A watchdog alarm
  /// re-rings if the user stalls or closes the app mid-challenge.
  Future<void> silenceForChallenge(RingSession s) async {
    final spec = byId(s.firingId);
    if (spec != null && spec.repeats) {
      // Re-arming the same id stops this ring and schedules the next
      // occurrence right away, so tomorrow is covered even if the app dies.
      await scheduler.arm(spec.id, spec.nextFire(DateTime.now()), prefs, body: roasts[prefs.roast]!.first);
    } else {
      await scheduler.disarm(s.firingId);
    }
    await armWatchdog();
  }

  Future<void> armWatchdog() =>
      scheduler.arm(Scheduler.watchdogId, DateTime.now().add(const Duration(seconds: 60)), prefs,
          body: 'Too slow. I came back.');

  Future<void> _stopRinging(RingSession s) async {
    await scheduler.disarm(Scheduler.watchdogId);
    if (await scheduler.isRinging(s.firingId) || byId(s.firingId)?.repeats != true) {
      await scheduler.disarm(s.firingId);
    }
  }

  /// A one-off alarm that has rung is done, whatever the outcome.
  void _retireIfOnce(RingSession s) {
    final spec = byId(s.alarm.id);
    if (spec != null && !spec.repeats && s.firingId == spec.id) {
      alarms[alarms.indexOf(spec)] = spec.copyWith(enabled: false);
    }
  }

  /// Called when the challenge is beaten.
  Future<void> recordWin(RingSession s, int seconds) async {
    await _stopRinging(s);
    if (!s.isTest) {
      streak++;
      history.add(WakeLog(at: DateTime.now(), seconds: seconds, challenge: s.rolled, failedWords: s.failedWords));
      if (s.firingId == Scheduler.snoozeId) _snoozeOf = null;
      _retireIfOnce(s);
    }
    _activeAlarm = null;
    _changed();
    await syncSchedule();
  }

  /// Burns an emergency skip: streak to zero, re-ring in five minutes.
  /// Returns the streak that was lost.
  Future<int> burnSkip(RingSession s) async {
    final lost = streak;
    await _stopRinging(s);
    if (!s.isTest) {
      streak = 0;
      history.add(WakeLog(at: DateTime.now(), seconds: 0, challenge: s.rolled, skipped: true));
      _retireIfOnce(s);
      _snoozeOf = s.alarm.id;
      await scheduler.arm(Scheduler.snoozeId, DateTime.now().add(const Duration(minutes: 5)), prefs,
          body: 'Five minutes are up. Streak: 0.');
    }
    _activeAlarm = null;
    _changed();
    await syncSchedule();
    return lost;
  }

  void endSession() {
    session?.dispose();
    session = null;
    notifyListeners();
  }
}
