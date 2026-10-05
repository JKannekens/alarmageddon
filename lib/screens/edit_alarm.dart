import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/fx.dart';

class EditAlarmScreen extends StatefulWidget {
  const EditAlarmScreen({super.key, this.existing, required this.onOpenPool});
  final AlarmSpec? existing;

  /// Jumps to the Settings tab (this route sits above the tab shell).
  final VoidCallback onOpenPool;
  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late AlarmSpec draft = widget.existing ??
      AlarmSpec(
        id: context.read<AppStore>().newAlarmId(),
        hour: 7,
        minute: 0,
        days: [true, true, true, true, true, false, false],
      );

  void _set(AlarmSpec next) => setState(() => draft = next);

  void _shiftHour(int by) => _set(draft.copyWith(hour: (draft.hour + by) % 24));
  void _shiftMinute(int by) => _set(draft.copyWith(minute: (draft.minute + by) % 60));

  void _save() {
    context.read<AppStore>().saveAlarm(draft);
    Navigator.of(context).pop();
  }

  void _delete() {
    context.read<AppStore>().deleteAlarm(draft.id);
    Navigator.of(context).pop();
  }

  void _openPool() {
    Navigator.of(context).pop();
    widget.onOpenPool();
  }

  @override
  Widget build(BuildContext context) {
    final pool = context.select<AppStore, Set<Challenge>>((s) => s.prefs.pool);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      body: SafeArea(
        child: FadeSlideIn(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Pill(
                      label: 'Cancel',
                      expand: false,
                      bg: AG.surface,
                      fg: AG.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      style: AG.t(13, weight: FontWeight.w600),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Text(widget.existing == null ? 'New alarm' : 'Edit alarm', style: AG.d(18)),
                    Pill(
                      label: 'Save',
                      expand: false,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      style: AG.t(13, weight: FontWeight.w700),
                      onTap: _save,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Spinner(
                          text: '${(draft.hour + 11) % 12 + 1}',
                          width: 110,
                          onUp: () => _shiftHour(1),
                          onDown: () => _shiftHour(-1),
                          onDragStep: _shiftHour,
                          label: 'hour',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(':', style: AG.d(70, color: AG.dim)),
                        ),
                        _Spinner(
                          text: draft.minute.toString().padLeft(2, '0'),
                          width: 120,
                          onUp: () => _shiftMinute(5),
                          onDown: () => _shiftMinute(-5),
                          onDragStep: _shiftMinute,
                          label: 'minute',
                        ),
                        const SizedBox(width: 4),
                        Pill(
                          label: draft.hour < 12 ? 'AM' : 'PM',
                          expand: false,
                          bg: AG.surface,
                          fg: AG.ink,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          style: AG.d(16),
                          onTap: () => _shiftHour(12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Drag the numbers for single minutes.',
                        textAlign: TextAlign.center, style: AG.t(11, color: AG.dim)),
                    const SizedBox(height: 22),
                    const SectionLabel('Repeat'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          GestureDetector(
                            onTap: () {
                              final days = [...draft.days];
                              days[i] = !days[i];
                              _set(draft.copyWith(days: days));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: draft.days[i] ? AG.lime : AG.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Text(dayLetters[i],
                                  style: AG.t(13,
                                      weight: FontWeight.w700, color: draft.days[i] ? AG.bg : AG.muted)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(describeDays(draft.days), style: AG.t(12, color: AG.muted)),
                    const SizedBox(height: 22),
                    const SectionLabel('Challenge'),
                    const SizedBox(height: 10),
                    Transform.rotate(
                      angle: -1.5 * pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(color: AG.lime, borderRadius: BorderRadius.circular(28)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Surprise me', style: AG.d(22, color: AG.bg)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rolled at random from: ${Challenge.values.where(pool.contains).map((c) => c.label).join(', ')}',
                                    style: AG.t(12, color: AG.bg, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                            Transform.rotate(
                              angle: 8 * pi / 180,
                              child: Text('?', style: AG.d(34, color: AG.bg)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _openPool,
                      child: Text('Change the pool in Settings', style: AG.t(12, color: AG.muted)),
                    ),
                    const SizedBox(height: 22),
                    const SectionLabel('Difficulty'),
                    const SizedBox(height: 10),
                    Segmented<Difficulty>(
                      options: Difficulty.values,
                      selected: draft.difficulty,
                      labelOf: (d) => d.label,
                      selectedBg: AG.pink,
                      onPick: (d) => _set(draft.copyWith(difficulty: d)),
                    ),
                    const SizedBox(height: 10),
                    Text(difficultyNotes[draft.difficulty]!, style: AG.t(12, color: AG.muted)),
                    if (widget.existing != null) ...[
                      const SizedBox(height: 22),
                      Center(
                        child: GestureDetector(
                          onTap: _delete,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('Delete alarm', style: AG.t(14, weight: FontWeight.w700, color: AG.pink)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big lime number with ▲/▼ arrows; also drags vertically one step per notch.
class _Spinner extends StatefulWidget {
  const _Spinner({
    required this.text,
    required this.width,
    required this.onUp,
    required this.onDown,
    required this.onDragStep,
    required this.label,
  });
  final String text;
  final double width;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<int> onDragStep;
  final String label;
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> {
  double _acc = 0;
  static const _notch = 14.0;

  Widget _arrow(String glyph, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(glyph, style: AG.t(18, color: AG.muted)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _arrow('▲', widget.onUp, 'Increase ${widget.label}'),
          GestureDetector(
            onVerticalDragStart: (_) => _acc = 0,
            onVerticalDragUpdate: (d) {
              _acc += d.delta.dy;
              while (_acc.abs() >= _notch) {
                final up = _acc < 0;
                widget.onDragStep(up ? 1 : -1);
                _acc += up ? _notch : -_notch;
              }
            },
            child: SizedBox(
              width: widget.width,
              child: Text(widget.text, textAlign: TextAlign.center, style: AG.d(84, color: AG.lime, height: 1)),
            ),
          ),
          _arrow('▼', widget.onDown, 'Decrease ${widget.label}'),
        ],
      );
}
