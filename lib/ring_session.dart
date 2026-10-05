import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'content.dart';
import 'models.dart';
import 'scheduler.dart';
import 'store.dart';

enum RingPhase { ringing, challenge, success, skipped }

/// One alarm going off, from the first ring to "Start the day".
class RingSession extends ChangeNotifier {
  RingSession({
    required this.store,
    required this.firingId,
    required this.alarm,
    required this.isTest,
    required List<Challenge> pool,
    required this.roastLine,
    required this.flash,
  }) : startedAt = DateTime.now() {
    rolled = pick(pool);
    // A slot-machine reel that always lands on the rolled challenge.
    reel = [for (var i = 0; i < 17; i++) pool[(i + rng.nextInt(pool.length)) % pool.length], rolled];
    _spinTimer = Timer(const Duration(milliseconds: 2500), () {
      spinning = false;
      notifyListeners();
    });
  }

  final AppStore store;
  final int firingId;
  final AlarmSpec alarm;
  final bool isTest;
  final String roastLine;
  final bool flash;
  final DateTime startedAt;

  late final Challenge rolled;
  late final List<Challenge> reel;
  Timer? _spinTimer;

  RingPhase phase = RingPhase.ringing;
  bool spinning = true;
  bool sheetOpen = false;

  /// The watchdog re-rang because the user stalled mid-challenge.
  bool nagging = false;

  final failedWords = <String>[];
  int resultSeconds = 0;
  int lostStreak = 0;
  DateTime _lastPoke = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  Difficulty get difficulty => alarm.difficulty;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void startChallenge() {
    if (spinning || phase != RingPhase.ringing) return;
    phase = RingPhase.challenge;
    _lastPoke = DateTime.now();
    _notify();
    store.silenceForChallenge(this);
  }

  /// Any challenge input. Keeps the watchdog from re-ringing while the user
  /// is actually working on it.
  void poke() {
    if (phase != RingPhase.challenge) return;
    final now = DateTime.now();
    if (nagging) {
      nagging = false;
      _lastPoke = now;
      _notify();
      store.scheduler.disarm(Scheduler.watchdogId).then((_) => store.armWatchdog());
    } else if (now.difference(_lastPoke) > const Duration(seconds: 15)) {
      _lastPoke = now;
      store.armWatchdog();
    }
  }

  void nag() {
    if (phase != RingPhase.challenge) return;
    nagging = true;
    _notify();
  }

  void addFailedWord(String word) => failedWords.add(word);

  Future<void> win() async {
    if (phase == RingPhase.success) return;
    resultSeconds = max(1, DateTime.now().difference(startedAt).inSeconds);
    phase = RingPhase.success;
    _notify();
    await store.recordWin(this, resultSeconds);
    _notify();
  }

  void openSkipSheet() {
    sheetOpen = true;
    _notify();
  }

  void closeSkipSheet() {
    sheetOpen = false;
    _notify();
  }

  bool get canSkip => isTest || store.skipsLeft > 0;

  Future<void> burnSkip() async {
    if (!canSkip) return;
    lostStreak = store.streak;
    sheetOpen = false;
    phase = RingPhase.skipped;
    _notify();
    await store.burnSkip(this);
    _notify();
  }

  void finish() => store.endSession();

  @override
  void dispose() {
    _disposed = true;
    _spinTimer?.cancel();
    super.dispose();
  }
}
