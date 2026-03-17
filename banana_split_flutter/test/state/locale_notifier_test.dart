import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:banana_split_flutter/state/locale_notifier.dart';
import 'dart:ui';

void main() {
  late LocaleNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifier = LocaleNotifier();
  });

  test('locale is null before load (system default)', () {
    expect(notifier.locale, isNull);
  });

  test('load with no saved preference keeps locale null', () async {
    await notifier.load();
    expect(notifier.locale, isNull);
  });

  test('setLocale updates locale and notifies listeners', () {
    var notified = false;
    notifier.addListener(() => notified = true);
    notifier.setLocale(const Locale('ru'));
    expect(notifier.locale, const Locale('ru'));
    expect(notified, isTrue);
  });

  test('setLocale persists to SharedPreferences', () async {
    notifier.setLocale(const Locale('tr'));
    // Allow the fire-and-forget SharedPreferences.getInstance().then() to complete
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'tr');
  });

  test('load reads persisted locale', () async {
    SharedPreferences.setMockInitialValues({'locale': 'ka'});
    final fresh = LocaleNotifier();
    await fresh.load();
    expect(fresh.locale, const Locale('ka'));
  });

  test('setLocale then load round-trips correctly', () async {
    notifier.setLocale(const Locale('uk'));
    // Allow the fire-and-forget SharedPreferences.getInstance().then() to complete
    await Future<void>.delayed(Duration.zero);
    final fresh = LocaleNotifier();
    await fresh.load();
    expect(fresh.locale, const Locale('uk'));
  });
}
