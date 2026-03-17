import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:banana_split_flutter/state/locale_notifier.dart';
import 'package:banana_split_flutter/widgets/language_selector.dart';

Widget buildTestApp({Locale locale = const Locale('en')}) {
  final notifier = LocaleNotifier();
  return ChangeNotifierProvider.value(
    value: notifier,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          actions: const [LanguageSelectorButton()],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows flag emoji button', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    // The button should show the US flag for English locale
    expect(find.text('🇺🇸'), findsOneWidget);
  });

  testWidgets('popup shows 6 language options', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    // Tap the flag button to open popup
    await tester.tap(find.text('🇺🇸'));
    await tester.pumpAndSettle();
    // Should see all 6 flags with language names
    expect(find.text('🇺🇸 English'), findsOneWidget);
    expect(find.text('🇷🇺 Русский'), findsOneWidget);
    expect(find.text('🇹🇷 Türkçe'), findsOneWidget);
    expect(find.text('🇧🇾 Беларуская'), findsOneWidget);
    expect(find.text('🇬🇪 ქართული'), findsOneWidget);
    expect(find.text('🇺🇦 Українська'), findsOneWidget);
  });

  testWidgets('selecting a locale updates LocaleNotifier', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇺🇸'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇷🇺 Русский'));
    await tester.pumpAndSettle();
    final notifier = tester
        .element(find.byType(LanguageSelectorButton))
        .read<LocaleNotifier>();
    expect(notifier.locale, const Locale('ru'));
  });
}
