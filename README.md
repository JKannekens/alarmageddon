# Alarmageddon

An alarm clock that won't stop until you prove you're awake. Each morning it rolls one challenge at random: sing on the beat, scan an object, do the math, or shake the phone. Your snooze button is dead. There are emergency skips, and each one costs you your streak.

The original Claude Design files are in [design/](design/).

## Stack

Flutter (iOS and Android from one codebase).

| Concern | Package |
| --- | --- |
| Ringing on lock and silent, background scheduling | `alarm` |
| Sing-on-beat detection (raw PCM loudness onsets) | `record` |
| Shake counting | `sensors_plus` |
| Scan viewfinder | `camera` |
| Scan check (on-device labelling) | `google_mlkit_image_labeling` |
| Persistence | `shared_preferences` |
| Permissions | `permission_handler` |

## Layout

```
lib/
  main.dart, app.dart     bootstrap; pushes the ring flow when an alarm fires
  store.dart              alarms, prefs, streak, history; arms and re-arms alarms
  ring_session.dart       one ring: reel roll, challenge, win or skip, watchdog
  scheduler.dart          wrapper over the alarm plugin (serialised calls)
  models.dart, content.dart
  screens/                onboarding, alarms list, edit, stats, settings
  ring/                   ringing screen, 4 challenges, success and skip screens
  widgets/                design effects (pulse, ripple, tickers, jitter) and controls
```

## Run

```bash
flutter test
flutter run -d chrome        # UI only: the web build can't schedule real alarms
flutter run                  # attached Android device or emulator
```

The scan check needs ML Kit, which only runs on Android and iOS. Without it (web, or the camera is denied) the scan challenge turns into math. To preview the scan UI anyway, add `--dart-define=FAKE_SCAN=true`: every scan then passes after a short "judging" delay.

## How ringing works

- The plugin has no repeating alarms. The store arms each alarm's next occurrence and re-arms it after it rings.
- The notification has no stop button. The only way out is through the app.
- When you start a challenge, the sound stops and tomorrow's occurrence is armed right away. A 60-second watchdog alarm re-rings if you stall or kill the app mid-challenge.
- An emergency skip zeroes the streak and re-rings in 5 minutes. Skips have a monthly quota.
- "Test the doom" fires a real alarm 3 seconds later. Test runs don't count toward stats.

## iPhone

iOS builds need macOS and Xcode. From Windows, use a cloud Mac (for example Codemagic) and an Apple Developer account to install on a device or ship via TestFlight.

The minimum iOS version is 15.5, because ML Kit requires it. `ios/Podfile` holds the ML Kit build settings.

iOS limitation: if you force-quit the app, iOS won't let it ring. The app shows a warning notification when that happens. Possible upgrades are AlarmKit on iOS 26+ (`flutter_alarmkit`), or a burst of backup notifications.

## Known gaps / next steps

- **Scan labels aren't tuned on real phones yet.** Each object maps to a few ML Kit labels (`scanTargets` in `content.dart`), and a scan passes when one shows up at 0.6 confidence or higher in 3 frames in a row over 0.8 s. Debug builds log what the model sees (`scan: Cup 0.91, …`), so you can check the labels and thresholds on a device. After 3 misses the user can switch to math, so a label the model doesn't know can't trap anyone.
- **Mic thresholds are fixed.** They may need tuning, or per-device calibration, on real phones.
- **Possible extras:** a back-to-bed check, a barcode challenge, and a snitch mode that texts a friend when you burn a skip.

## Licenses

Caprasimo and Figtree are under the SIL Open Font License ([assets/fonts/](assets/fonts/)). The alarm tone is synthesised by `tool/gen_alarm_sound.py`.
