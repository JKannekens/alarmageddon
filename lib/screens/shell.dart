import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'home.dart';
import 'settings.dart';
import 'stats.dart';

/// Which bottom tab is showing. Provided so other screens can jump tabs.
class ShellTab extends ValueNotifier<int> {
  ShellTab() : super(0);
  static const alarms = 0, stats = 1, settings = 2;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final tab = ShellTab();

  @override
  void dispose() {
    tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: tab,
        child: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (_, i, _) => Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: i,
                    children: const [HomeScreen(), StatsScreen(), SettingsScreen()],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 22 + MediaQuery.paddingOf(context).bottom / 2,
                  child: _TabBar(index: i, onPick: (v) => tab.value = v),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onPick});
  final int index;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AG.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            for (final (i, label) in const [(0, 'Alarms'), (1, 'Stats'), (2, 'Settings')])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    onTap: () => onPick(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 3, right: i == 2 ? 0 : 3),
                      decoration: BoxDecoration(
                        color: i == index ? AG.lime : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AG.t(13, weight: FontWeight.w700, color: i == index ? AG.bg : AG.muted),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
