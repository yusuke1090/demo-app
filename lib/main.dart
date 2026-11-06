import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'screens/cows_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/soil_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(FarmApp(state: AppState(prefs: prefs)));
}

class FarmApp extends StatelessWidget {
  const FarmApp({
    super.key,
    required this.state,
    this.fontFamily,
    this.themeMode = ThemeMode.system,
  });

  final AppState state;
  final String? fontFamily;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: '農場モニター',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, fontFamily: fontFamily),
        darkTheme: buildTheme(Brightness.dark, fontFamily: fontFamily),
        themeMode: themeMode,
        // 日本語の字形で表示するために必要
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _tab = widget.initialTab;

  void _select(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    const titles = ['農場モニター', '土の水分', '牛の行動', '設定'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onOpenTab: _select),
          const SoilScreen(),
          const CowsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'ホーム'),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            label: '土',
          ),
          NavigationDestination(icon: Icon(Icons.pets_outlined), label: '牛'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
