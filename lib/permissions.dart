import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asks for everything the challenges need, one prompt after another.
/// Denials are fine: each challenge has its own fallback.
Future<void> requestEverything() async {
  if (kIsWeb) return;
  final perms = [Permission.notification, Permission.microphone, Permission.camera];
  if (defaultTargetPlatform == TargetPlatform.android) perms.add(Permission.scheduleExactAlarm);
  try {
    await perms.request();
  } catch (_) {
    // Unsupported on this platform; carry on.
  }
}
