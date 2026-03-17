# Language Selector Design

## Goal

Add a flag-based language selector to every screen's AppBar (upper right). Switching language takes effect immediately. The user's choice persists across app restarts via `shared_preferences`.

## Supported Locales

| Locale | Flag | Language   |
|--------|------|------------|
| en     | 🇺🇸  | English    |
| ru     | 🇷🇺  | Russian    |
| tr     | 🇹🇷  | Turkish    |
| be     | 🇧🇾  | Belarusian |
| ka     | 🇬🇪  | Georgian   |
| uk     | 🇺🇦  | Ukrainian  |

## Architecture

### LocaleNotifier (`lib/state/locale_notifier.dart`)

A `ChangeNotifier` that manages the current locale and persists the choice.

- `Locale? _locale` — `null` on first launch (system default). Once the user picks a language, there is no "reset to system" option; they can only switch between the 6 explicit languages. This is intentional — the selector is a direct language picker, not a system-preference override.
- `Locale? get locale` — returns the stored locale (or `null` for system default on first launch).
- `Future<void> load()` — reads the saved locale code from `SharedPreferences` key `locale`. If present, sets `_locale` to the corresponding `Locale`.
- `void setLocale(Locale locale)` — sets `_locale`, saves the language code to `SharedPreferences`, calls `notifyListeners()`.

Registered as a `ChangeNotifierProvider` in `main.dart` alongside existing providers. Created and loaded before `runApp()`.

### LanguageSelectorButton (`lib/widgets/language_selector.dart`)

A `PopupMenuButton<Locale>` widget placed in AppBar `actions`.

- The button displays the current locale's flag emoji.
- The popup menu lists all 6 supported locales, each showing its flag emoji and language name (e.g., "🇺🇸 English"). The currently active locale is highlighted via `PopupMenuButton.initialValue`.
- `onSelected` calls `context.read<LocaleNotifier>().setLocale(locale)`.
- A static `Map<String, String>` maps locale codes to flag emojis.
- The current locale is determined from `Localizations.localeOf(context)` to show the correct flag on the button, even when `LocaleNotifier.locale` is `null` (system default).

### MaterialApp Wiring

`BananaSplitApp` changes from `StatelessWidget` to use `Consumer<LocaleNotifier>` (or `context.watch<LocaleNotifier>()`). The `MaterialApp.locale` property is set to `localeNotifier.locale`. When `null`, Flutter falls back to system locale resolution. When set, it overrides the system locale and the entire widget tree rebuilds immediately.

### AppBar Integration

The `LanguageSelectorButton` is added to `actions` in:

1. **`HomeShell`** (`lib/main.dart`) — the main AppBar visible on Create, Restore, and About tabs.
2. **`PrivacyPolicyScreen`** (`lib/screens/privacy_policy_screen.dart`) — its own AppBar. Added alongside the existing "View online" button.

Any future screen with its own AppBar should include this widget.

### Startup Flow

```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ...
  final localeNotifier = LocaleNotifier();
  await localeNotifier.load();    // read persisted choice
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeNotifier),
        ...existing providers...
      ],
      child: const BananaSplitApp(),  // now reads LocaleNotifier
    ),
  );
}
```

## Dependencies

- Add `shared_preferences: ^2.3.0` to `pubspec.yaml`.

## Platform Notes

- On Windows, flag emoji do not render as graphical flags — they appear as two-letter country code ligatures (e.g., "US" in a box). This is acceptable because each menu item also shows the language name, so usability is preserved. The button itself will show the two-letter code on Windows, which is still recognizable.
- No platform-specific code is needed.

## Testing

- Unit tests for `LocaleNotifier`: verify `setLocale` updates locale, verify `load` reads from prefs.
- Widget test for `LanguageSelectorButton`: verify popup shows 6 items, verify selecting one calls `setLocale`.
