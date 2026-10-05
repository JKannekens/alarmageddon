import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Thin wrapper over the `alarm` plugin.
///
/// The plugin can't schedule repeating alarms, so the store arms each alarm's
/// next occurrence and re-arms after it rings. Calls are serialised because
/// concurrent set/stop crashes the iOS side.
class Scheduler {
  Scheduler({bool? supported}) : supported = supported ?? !kIsWeb;

  static const testId = 900001;
  static const snoozeId = 900002;
  static const watchdogId = 900003;

  static const _sound = 'assets/sounds/doom.wav';

  /// The plugin has no web implementation; the web build is UI-only.
  final bool supported;

  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> init() async {
    if (!supported) return;
    await Alarm.init();
    await Alarm.setWarningNotificationOnKill(
      'Keep me open',
      "Swiping me away means I can't ring. Open me again before bed.",
    );
  }

  /// Ids currently ringing. Replays the current value on listen.
  Stream<Set<int>> get ringing =>
      supported ? Alarm.ringing.map((s) => s.alarms.map((a) => a.id).toSet()) : const Stream.empty();

  AlarmSettings _settings(int id, DateTime at, Prefs prefs, String body) => AlarmSettings(
        id: id,
        dateTime: at,
        assetAudioPath: _sound,
        loopAudio: true,
        vibrate: prefs.vibrate,
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        volumeSettings: prefs.escalate
            ? VolumeSettings.staircaseFade(
                volume: 0.9,
                volumeEnforced: true,
                fadeSteps: [
                  VolumeFadeStep(Duration.zero, 0.35),
                  VolumeFadeStep(const Duration(seconds: 30), 0.65),
                  VolumeFadeStep(const Duration(seconds: 60), 1.0),
                ],
              )
            : const VolumeSettings.fixed(volume: 0.9, volumeEnforced: true),
        // No stop button: the only way out is through the app.
        notificationSettings: NotificationSettings(
          title: 'Alarmageddon',
          body: body,
          androidStopAlarmOnDismiss: false,
        ),
      );

  Future<void> arm(int id, DateTime at, Prefs prefs, {String body = 'Get up. Prove it.'}) => _serial(() async {
        if (!supported) return;
        final next = _settings(id, at, prefs, body);
        final existing = await Alarm.getAlarm(id);
        if (existing == next) return;
        await Alarm.set(alarmSettings: next);
      });

  Future<void> disarm(int id) => _serial(() async {
        if (!supported) return;
        if (await Alarm.getAlarm(id) != null || await Alarm.isRinging(id)) await Alarm.stop(id);
      });

  Future<bool> isRinging(int id) => supported ? Alarm.isRinging(id) : Future.value(false);
}
