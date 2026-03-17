# Language Selector Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent, flag-based language selector to every AppBar so users can switch the app language instantly.

**Architecture:** A `LocaleNotifier` ChangeNotifier manages the active locale and persists it via `shared_preferences`. A reusable `LanguageSelectorButton` widget (PopupMenuButton with flag emojis) is placed in every AppBar's `actions`. `MaterialApp.locale` is bound to the notifier so the entire widget tree rebuilds on language change.

**Tech Stack:** Flutter, Provider, shared_preferences, flutter_localizations (existing)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/state/locale_notifier.dart` | Locale state management + persistence |
| Create | `lib/widgets/language_selector.dart` | Flag popup menu widget |
| Create | `test/state/locale_notifier_test.dart` | Unit tests for LocaleNotifier |
| Create | `test/widgets/language_selector_test.dart` | Widget tests for LanguageSelectorButton |
| Modify | `pubspec.yaml` | Add `shared_preferences` dependency |
| Modify | `lib/main.dart` | Wire LocaleNotifier into providers + MaterialApp + AppBar |
| Modify | `lib/screens/privacy_policy_screen.dart` | Add LanguageSelectorButton to AppBar actions |

---

## Chunk 1: Core State and Widget

### Task 1: Add shared_preferences dependency

**Files:**
- Modify: `banana_split_flutter/pubspec.yaml:24-43`

- [ ] **Step 1: Add shared_preferences to dependencies**

In `banana_split_flutter/pubspec.yaml`, add `shared_preferences: ^2.3.0` after the `path_provider` line (line 40):

```yaml
  path_provider: ^2.1.4
  shared_preferences: ^2.3.0
  permission_handler: ^11.3.1
```

- [ ] **Step 2: Run pub get**

```bash
cd banana_split_flutter && flutter pub get
```

Expected: resolves successfully, no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add shared_preferences for locale persistence"
```

---

### Task 2: Create LocaleNotifier

**Files:**
- Create: `banana_split_flutter/lib/state/locale_notifier.dart`
- Create: `banana_split_flutter/test/state/locale_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `banana_split_flutter/test/state/locale_notifier_test.dart`:

```dart
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
    final fresh = LocaleNotifier();
    await fresh.load();
    expect(fresh.locale, const Locale('uk'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd banana_split_flutter && flutter test test/state/locale_notifier_test.dart
```

Expected: compilation error — `locale_notifier.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `banana_split_flutter/lib/state/locale_notifier.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd banana_split_flutter && flutter test test/state/locale_notifier_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/state/locale_notifier.dart test/state/locale_notifier_test.dart
git commit -m "feat: add LocaleNotifier with persistence via shared_preferences"
```

---

### Task 3: Create LanguageSelectorButton widget

**Files:**
- Create: `banana_split_flutter/lib/widgets/language_selector.dart`
- Create: `banana_split_flutter/test/widgets/language_selector_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `banana_split_flutter/test/widgets/language_selector_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd banana_split_flutter && flutter test test/widgets/language_selector_test.dart
```

Expected: compilation error — `language_selector.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `banana_split_flutter/lib/widgets/language_selector.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd banana_split_flutter && flutter test test/widgets/language_selector_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/language_selector.dart test/widgets/language_selector_test.dart
git commit -m "feat: add LanguageSelectorButton widget with flag emoji popup"
```

---

## Chunk 2: Integration

### Task 4: Wire LocaleNotifier into main.dart

**Files:**
- Modify: `banana_split_flutter/lib/main.dart`

This task modifies `main.dart` in three places:
1. Add the import for `LocaleNotifier` and `LanguageSelectorButton`.
2. In `main()`, create and load `LocaleNotifier` before `runApp()`, add it to `MultiProvider` using `ChangeNotifierProvider.value`.
3. In `BananaSplitApp.build()`, use `Consumer<LocaleNotifier>` to pass `locale` to `MaterialApp`.
4. In `_HomeShellState.build()`, add `LanguageSelectorButton()` to the AppBar's `actions`.

- [ ] **Step 1: Add imports**

At the top of `banana_split_flutter/lib/main.dart`, after the existing imports (after line 13), add:

```dart
import 'package:banana_split_flutter/state/locale_notifier.dart';
import 'package:banana_split_flutter/widgets/language_selector.dart';
```

- [ ] **Step 2: Modify main() to create and load LocaleNotifier**

In `main()`, after `passphraseGenerator` is created (after line 21) and before `LicenseRegistry.addLicense` (line 23), add:

```dart
  final localeNotifier = LocaleNotifier();
  await localeNotifier.load();
```

- [ ] **Step 3: Add LocaleNotifier to MultiProvider and use .value for it**

Find the `runApp(` block and replace it with (line numbers refer to the original file; they shift after earlier steps add lines — use code pattern matching):

```dart
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeNotifier),
        ChangeNotifierProvider(
          create: (_) => CreateNotifier(passphraseGenerator),
        ),
        ChangeNotifierProvider(
          create: (_) => RestoreNotifier(),
        ),
      ],
      child: const BananaSplitApp(),
    ),
  );
```

- [ ] **Step 4: Wire MaterialApp.locale via Consumer**

Find the `class BananaSplitApp extends StatelessWidget` block and replace the entire class with:

```dart
class BananaSplitApp extends StatelessWidget {
  const BananaSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.amber;

    return Consumer<LocaleNotifier>(
      builder: (context, localeNotifier, _) => MaterialApp(
        title: 'Banana Split',
        locale: localeNotifier.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
```

- [ ] **Step 5: Add LanguageSelectorButton to HomeShell AppBar**

In `_HomeShellState.build()`, find the `appBar: AppBar(` block and add `actions`:

```dart
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [LanguageSelectorButton()],
      ),
```

- [ ] **Step 6: Run all tests**

```bash
cd banana_split_flutter && flutter test
```

Expected: all tests pass (existing + new).

- [ ] **Step 7: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire LocaleNotifier into MaterialApp and add language selector to main AppBar"
```

---

### Task 5: Add LanguageSelectorButton to PrivacyPolicyScreen

**Files:**
- Modify: `banana_split_flutter/lib/screens/privacy_policy_screen.dart:17-23`

- [ ] **Step 1: Add import**

At the top of `banana_split_flutter/lib/screens/privacy_policy_screen.dart`, after the existing imports, add:

```dart
import 'package:banana_split_flutter/widgets/language_selector.dart';
```

- [ ] **Step 2: Add LanguageSelectorButton to actions**

In the `build()` method, modify the `actions` list in the AppBar (line 17–23) to include `LanguageSelectorButton()`:

```dart
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(_privacyUrl)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.privacyPolicyViewOnline),
          ),
          const LanguageSelectorButton(),
        ],
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/privacy_policy_screen.dart
git commit -m "feat: add language selector to PrivacyPolicyScreen AppBar"
```

---

### Task 6: Run full test suite and verify

**Files:** none (verification only)

- [ ] **Step 1: Run all tests**

```bash
cd banana_split_flutter && flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues found.

- [ ] **Step 3: Manual smoke test (if device available)**

```bash
cd banana_split_flutter && flutter run
```

Verify:
- Flag emoji button visible in AppBar on all tabs (Create, Restore, About).
- Tapping the flag opens a popup with 6 language options (flag + name).
- Selecting a language instantly switches all UI text.
- Restarting the app preserves the selected language.
- Navigate to Privacy Policy screen — flag selector is also in that AppBar.
