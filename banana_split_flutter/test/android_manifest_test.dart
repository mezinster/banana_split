import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the manifest entries Open / Share depend on. Nothing in Dart fails
/// when one goes missing — the chooser just comes up nearly empty on Android
/// 11+, or the merged APK quietly gains permissions.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('declares package visibility for ACTION_VIEW on any MIME type', () {
    final queries =
        RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest);
    expect(queries, isNotNull, reason: 'no <queries> block');
    final intent = RegExp(
      r'<intent>\s*<action android:name="android.intent.action.VIEW"\s*/>'
      r'\s*<data android:mimeType="\*/\*"\s*/>\s*</intent>',
    );
    expect(intent.hasMatch(queries!.group(1)!), isTrue);
  });

  // READ_EXTERNAL_STORAGE matters most: it would apply through API 32 (the
  // only other storage permission, camerax's WRITE, stops at API 28), and a
  // secret-sharing app should not acquire a read permission as a side effect
  // of a plugin that only ever opens the app's own files.
  for (final permission in [
    'READ_EXTERNAL_STORAGE',
    'READ_MEDIA_IMAGES',
    'READ_MEDIA_VIDEO',
    'READ_MEDIA_AUDIO',
  ]) {
    test('strips $permission merged in by open_filex', () {
      final removal = RegExp(
        '<uses-permission\\s+android:name="android.permission.$permission"'
        '\\s+tools:node="remove"\\s*/>',
      );
      expect(removal.hasMatch(manifest), isTrue);
    });
  }
}
