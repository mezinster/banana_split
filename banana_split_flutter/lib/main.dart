import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
