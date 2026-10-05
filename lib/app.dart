import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ring/ring_flow.dart';
import 'ring_session.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class AlarmageddonApp extends StatefulWidget {
  const AlarmageddonApp({super.key});
  @override
  State<AlarmageddonApp> createState() => _AlarmageddonAppState();
}

class _AlarmageddonAppState extends State<AlarmageddonApp> {
  late final AppStore store = context.read<AppStore>();
  RingSession? _shown;

  @override
  void initState() {
    super.initState();
    store.addListener(_syncRingRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRingRoute());
  }

  @override
  void dispose() {
    store.removeListener(_syncRingRoute);
    super.dispose();
  }

  /// Puts the ring flow on top of whatever is open when an alarm fires, and
  /// returns to the alarm list when the session ends.
  void _syncRingRoute() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final s = store.session;
    if (s != null && _shown != s) {
      _shown = s;
      WakelockPlus.enable().ignore();
      nav.push(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => PopScope(canPop: false, child: RingFlow(session: s)),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ));
    } else if (s == null && _shown != null) {
      _shown = null;
      WakelockPlus.disable().ignore();
      nav.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Alarmageddon',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AG.theme(),
        home: Selector<AppStore, bool>(
          selector: (_, s) => s.onboarded,
          builder: (_, onboarded, _) =>
              onboarded ? const MainShell() : OnboardingScreen(onDone: store.onboardingDone),
        ),
      );
}
