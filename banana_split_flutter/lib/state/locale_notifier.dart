import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  static const _key = 'locale';

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_key, locale.languageCode);
    });
  }
}
