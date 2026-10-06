import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../content.dart';

/// Decides when the camera has really seen the target, so one lucky frame
/// can't pass: it has to show up in [frames] labelled frames in a row,
/// spanning at least [hold].
class ScanJudge {
  ScanJudge(
    this.target, {
    this.minConfidence = .6,
    this.frames = 3,
    this.hold = const Duration(milliseconds: 800),
  });

  final ScanTarget target;
  final double minConfidence;
  final int frames;
  final Duration hold;

  int _streak = 0;
  DateTime? _since;

  bool sees(List<ImageLabel> labels) =>
      labels.any((l) => l.confidence >= minConfidence && target.labels.contains(l.label.toLowerCase()));

  /// Feeds one frame's labels. True once the target is confirmed.
  bool add(List<ImageLabel> labels, DateTime at) {
    if (!sees(labels)) {
      reset();
      return false;
    }
    _since ??= at;
    _streak++;
    return _streak >= frames && at.difference(_since!) >= hold;
  }

  void reset() {
    _streak = 0;
    _since = null;
  }
}
