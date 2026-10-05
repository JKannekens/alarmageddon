import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Listens to the microphone and reports the moment each sung syllable
/// starts (a jump in loudness), timestamped on the caller's clock.
class OnsetMic {
  OnsetMic({required this.clockMs, required this.onOnset});

  /// Current time on the challenge clock, in milliseconds.
  final double Function() clockMs;
  final void Function(double atMs) onOnset;

  static const _rate = 16000;
  static const _frame = 320; // 20 ms
  static const _on = .06, _off = .03;
  static const _refractoryMs = 180.0;

  final _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _above = false;
  double _lastOnset = -1e9;

  /// Most recent loudness, 0..1, for the level meter.
  double level = 0;

  Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;
      final stream = await _rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _rate,
        numChannels: 1,
      ));
      _sub = stream.listen(_onChunk);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onChunk(Uint8List bytes) {
    final arrival = clockMs();
    final data = ByteData.sublistView(bytes);
    final n = bytes.lengthInBytes ~/ 2;
    final chunkMs = n * 1000 / _rate;
    for (var start = 0; start + _frame <= n; start += _frame) {
      var sum = 0.0;
      for (var i = start; i < start + _frame; i++) {
        final v = data.getInt16(i * 2, Endian.little) / 32768;
        sum += v * v;
      }
      final rms = sqrt(sum / _frame);
      level = (rms * 6).clamp(0, 1);
      // Place the frame in time: chunks arrive after they were recorded.
      final at = arrival - chunkMs + (start + _frame) * 1000 / _rate;
      if (rms > _on && !_above && at - _lastOnset > _refractoryMs) {
        _above = true;
        _lastOnset = at;
        onOnset(at);
      } else if (rms < _off) {
        _above = false;
      }
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    await _rec.dispose();
  }
}
