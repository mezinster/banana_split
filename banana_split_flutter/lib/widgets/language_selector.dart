import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:banana_split_flutter/state/locale_notifier.dart';

class LanguageSelectorButton extends StatelessWidget {
  const LanguageSelectorButton({super.key});

  static const _localeData = [
    (locale: Locale('en'), flag: '🇺🇸', name: 'English'),
    (locale: Locale('ru'), flag: '🇷🇺', name: 'Русский'),
    (locale: Locale('tr'), flag: '🇹🇷', name: 'Türkçe'),
    (locale: Locale('be'), flag: '🇧🇾', name: 'Беларуская'),
    (locale: Locale('ka'), flag: '🇬🇪', name: 'ქართული'),
    (locale: Locale('uk'), flag: '🇺🇦', name: 'Українська'),
  ];

  static String _flagForLocale(Locale locale) {
    for (final entry in _localeData) {
      if (entry.locale.languageCode == locale.languageCode) {
        return entry.flag;
      }
    }
    return '🇺🇸';
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    return PopupMenuButton<Locale>(
      initialValue: currentLocale,
      onSelected: (locale) {
        context.read<LocaleNotifier>().setLocale(locale);
      },
      itemBuilder: (context) => _localeData
          .map(
            (entry) => PopupMenuItem<Locale>(
              value: entry.locale,
              child: Text('${entry.flag} ${entry.name}'),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          _flagForLocale(currentLocale),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
