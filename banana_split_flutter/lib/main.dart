import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:banana_split_flutter/crypto/passphrase.dart';
import 'package:banana_split_flutter/state/create_notifier.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/screens/create_screen.dart';
import 'package:banana_split_flutter/screens/restore_screen.dart';
import 'package:banana_split_flutter/screens/about_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final wordlistContent =
      await rootBundle.loadString('assets/wordlist.txt');
  final passphraseGenerator =
      PassphraseGenerator.fromString(wordlistContent);

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Banana Split'],
      'GNU General Public License v3.0\n\n'
      'This program is free software: you can redistribute it and/or modify '
      'it under the terms of the GNU General Public License as published by '
      'the Free Software Foundation, either version 3 of the License, or '
      '(at your option) any later version.\n\n'
      'This program is distributed in the hope that it will be useful, '
      'but WITHOUT ANY WARRANTY; without even the implied warranty of '
      'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the '
      'GNU General Public License for more details.\n\n'
      'You should have received a copy of the GNU General Public License '
      'along with this program. If not, see https://www.gnu.org/licenses/.',
    );
  });

  runApp(
    MultiProvider(
      providers: [
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
}

class BananaSplitApp extends StatelessWidget {
  const BananaSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.amber;

    return MaterialApp(
      title: 'Banana Split',
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
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    CreateScreen(),
    RestoreScreen(),
    AboutScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.lock_outline),
      selectedIcon: Icon(Icons.lock),
      label: 'Create',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_scanner_outlined),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: 'Restore',
    ),
    NavigationDestination(
      icon: Icon(Icons.info_outline),
      selectedIcon: Icon(Icons.info),
      label: 'About',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banana Split'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
