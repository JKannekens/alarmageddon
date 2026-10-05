import 'package:alarmageddon/models.dart';
import 'package:alarmageddon/ring/ring_flow.dart';
import 'package:alarmageddon/ring_session.dart';
import 'package:alarmageddon/scheduler.dart';
import 'package:alarmageddon/screens/edit_alarm.dart';
import 'package:alarmageddon/screens/onboarding.dart';
import 'package:alarmageddon/screens/shell.dart';
import 'package:alarmageddon/store.dart';
import 'package:alarmageddon/theme.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lays out every screen at phone size and fails on any layout/render error.
void main() {
  late AppStore store;

  // Real fonts, so text measures like it does on a phone.
  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
      }
      await loader.load();
    }

    await load('Caprasimo', ['Caprasimo-Regular.ttf']);
    await load('Figtree', ['Figtree-Regular.ttf', 'Figtree-SemiBold.ttf', 'Figtree-Bold.ttf']);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.load(Scheduler(supported: false));
    store.alarms = [
      AlarmSpec(id: 1, hour: 6, minute: 30, days: [true, true, true, true, true, false, false]),
      AlarmSpec(id: 2, hour: 8, minute: 0, days: [false, false, false, false, false, true, false], enabled: false),
    ];
    store.streak = 12;
    store.history = [
      WakeLog(at: DateTime.now(), seconds: 95, challenge: Challenge.beat, failedWords: ['Parrot']),
    ];
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(theme: AG.theme(), home: child),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  RingSession session(Challenge rolled) {
    for (var i = 0; i < 200; i++) {
      final s = RingSession(
        store: store,
        firingId: Scheduler.testId,
        alarm: store.alarms.first,
        isTest: true,
        pool: [rolled],
        roastLine: 'Get up.',
        flash: false,
      );
      if (s.rolled == rolled) return s;
      s.dispose();
    }
    throw StateError('unreachable');
  }

  testWidgets('onboarding', (tester) async {
    await pump(tester, OnboardingScreen(onDone: () {}));
    expect(find.text('Your snooze button is dead.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("I'll pick your poison."), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Let me in.'), findsOneWidget);
  });

  testWidgets('shell tabs', (tester) async {
    await pump(tester, const MainShell());
    expect(find.text('6:30'), findsOneWidget);
    expect(find.text('ALSO SCHEDULED'), findsOneWidget);
    await tester.tap(find.text('Stats'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Your record'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Replay onboarding'), findsOneWidget);
  });

  testWidgets('edit alarm', (tester) async {
    await pump(tester, EditAlarmScreen(existing: store.alarms.first, onOpenPool: () {}));
    expect(find.text('Edit alarm'), findsOneWidget);
    await tester.tap(find.text('▲').first);
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('ringing screen, reel and skip sheet', (tester) async {
    final s = session(Challenge.math);
    await pump(tester, RingFlow(session: s));
    expect(find.text('6:30'), findsOneWidget);
    expect(find.text('Rolling…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Do the math'), findsOneWidget);
    s.openSkipSheet();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Burn it'), findsOneWidget);
    s.closeSkipSheet();
    await tester.pump(const Duration(milliseconds: 400));
    s.dispose();
  });

  for (final c in Challenge.values) {
    testWidgets('challenge: ${c.name}', (tester) async {
      final s = session(c)
        ..spinning = false
        ..phase = RingPhase.challenge;
      await pump(tester, RingFlow(session: s));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      // Unmount so timers and streams are cleaned up before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      s.dispose();
    });
  }

  testWidgets('beat miss screen after silence', (tester) async {
    final s = session(Challenge.beat)
      ..spinning = false
      ..phase = RingPhase.challenge;
    await pump(tester, RingFlow(session: s));
    // Count-in plus the first beat's window passes with no tap.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Missed.'), findsOneWidget);
    expect(s.failedWords, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  testWidgets('math challenge accepts the right answer', (tester) async {
    final s = session(Challenge.math)
      ..spinning = false
      ..phase = RingPhase.challenge;
    await pump(tester, RingFlow(session: s));
    final q = tester.widget<Text>(find.textContaining(' × ')).data!;
    final m = RegExp(r'(\d+) × (\d+) \+ (\d+)').firstMatch(q)!;
    final answer = int.parse(m[1]!) * int.parse(m[2]!) + int.parse(m[3]!);
    for (final d in '$answer'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await tester.tap(find.text('✓'));
    await tester.pump();
    expect(find.text("Correct. Don't celebrate yet."), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('outcome screens', (tester) async {
    final s = session(Challenge.shake)
      ..spinning = false
      ..resultSeconds = 47
      ..phase = RingPhase.success;
    await pump(tester, RingFlow(session: s));
    expect(find.text("You're alive."), findsOneWidget);
    s
      ..lostStreak = 12
      ..phase = RingPhase.skipped;
    s.closeSkipSheet(); // notifies
    await tester.pump(const Duration(seconds: 4));
    expect(find.text("Fine. I'm awake."), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
