import 'package:flutter/material.dart';

import '../theme.dart';

/// Anything tappable that shrinks a little while pressed (the design's
/// `style-active="transform:scale(.96)"`).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.pressedScale = .96, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fully rounded button used everywhere in the design.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.onTap,
    this.bg = AG.lime,
    this.fg = AG.bg,
    this.padding = const EdgeInsets.all(18),
    this.style,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final EdgeInsets padding;

  /// Defaults to the display face at 19px.
  final TextStyle? style;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: (style ?? AG.d(19)).copyWith(color: fg),
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: expand ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: expand ? text : Center(widthFactor: 1, heightFactor: 1, child: text),
      ),
    );
  }
}

/// The lime/grey switch.
class AgToggle extends StatelessWidget {
  const AgToggle({super.key, required this.on, required this.onTap, this.label});
  final bool on;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: on,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: on ? AG.lime : AG.surfaceHi, borderRadius: BorderRadius.circular(999)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: on ? AG.bg : AG.dim, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
}

/// Pill-shaped segmented picker (difficulty, roast level).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onPick,
    this.selectedBg = AG.lime,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onPick;
  final Color selectedBg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AG.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            for (final o in options)
              Expanded(
                child: GestureDetector(
                  onTap: () => onPick(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                    decoration: BoxDecoration(
                      color: o == selected ? selectedBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      labelOf(o),
                      textAlign: TextAlign.center,
                      style: AG.t(13, weight: FontWeight.w700, color: o == selected ? AG.bg : AG.muted),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AG.label);
}

/// Rounded chip with a speech-bubble corner, used for roast quotes.
class RoastBubble extends StatelessWidget {
  const RoastBubble(this.text, {super.key, this.bg = AG.plum, this.fg = AG.plumInk});
  final String text;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
            bottomRight: Radius.circular(26),
            bottomLeft: Radius.circular(8),
          ),
        ),
        child: Text(text, style: AG.t(14, color: fg, height: 1.4)),
      );
}

/// Small rounded tag (challenge, days, streak) on the home screen.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.bg, this.fg = AG.ink});
  final String text;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AG.t(12, color: fg)),
      );
}
